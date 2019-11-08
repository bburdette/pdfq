module Main exposing (..)

import Browser as B
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import File exposing (File)
import File.Select as FS
import Html exposing (Html)
import Http
import Json.Decode as JD
import Json.Encode as JE
import PdfElement
import PdfList
import PdfViewer
import PublicInterface as PI
import Task


type Page
    = View
    | List


type alias Model =
    { viewerModel : PdfViewer.Model
    , listModel : PdfList.Model
    , location : String
    , page : Page
    }


type Msg
    = ViewerMsg PdfViewer.Msg
    | ListMsg PdfList.Msg
    | ServerResponse (Result Http.Error PI.ServerResponse)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ViewerMsg vm ->
            let
                ( vmod, vcmd ) =
                    PdfViewer.update vm model.viewerModel
            in
            ( { model
                | viewerModel = vmod
                , page = View
              }
            , Cmd.map ViewerMsg vcmd
            )

        ListMsg lm ->
            let
                ( lmod, lcmd ) =
                    PdfList.update lm model.listModel
            in
            ( { model | listModel = lmod }
            , case lcmd of
                PdfList.None ->
                    Cmd.none

                PdfList.Open pi ->
                    Cmd.map ViewerMsg <|
                        PdfViewer.openPdfUrl pi.fileName
                            (Debug.log "blah" <| model.location ++ "/pdfs/" ++ pi.fileName)
            )

        ServerResponse sr ->
            case sr of
                Err e ->
                    ( model, Cmd.none )

                Ok isr ->
                    case isr of
                        PI.ServerError e ->
                            ( model, Cmd.none )

                        PI.FileListReceived lst ->
                            let
                                plm =
                                    model.listModel
                            in
                            ( { model
                                | listModel =
                                    { plm | pdfs = lst }
                              }
                            , Cmd.none
                            )


view : Model -> Html Msg
view model =
    E.layout
        []
    <|
        case model.page of
            List ->
                E.map ListMsg <|
                    PdfList.view model.listModel

            View ->
                E.map ViewerMsg <|
                    PdfViewer.view model.viewerModel


type alias Flags =
    { location : String }


mkPublicHttpReq : String -> PI.SendMsg -> Cmd Msg
mkPublicHttpReq location msg =
    Http.post
        { url = location ++ "/public"
        , body = Http.jsonBody (PI.encodeSendMsg msg)
        , expect = Http.expectJson ServerResponse PI.decodeServerResponse
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { viewerModel = PdfViewer.init
      , listModel = { pdfs = [] }
      , location = flags.location
      , page = List
      }
    , mkPublicHttpReq flags.location PI.GetFileList
    )


main : Program Flags Model Msg
main =
    B.element
        { init = init
        , subscriptions = \_ -> Sub.map ViewerMsg PdfViewer.pdfreceive
        , view = view
        , update = update
        }
