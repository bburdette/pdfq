module Main exposing (..)

import Browser as B
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import ErrorView as EV
import File exposing (File)
import File.Select as FS
import Html exposing (Html)
import Http
import Json.Decode as JD
import Json.Encode as JE
import PdfDoc as PD
import PdfElement
import PdfList as PL
import PdfViewer
import PublicInterface as PI
import Task


type Page
    = Viewer (PdfViewer.Model PL.Model)
    | List PL.Model
    | Loading
    | ErrorView (EV.Model Page)


type alias Model =
    { location : String
    , page : Page
    }


type Msg
    = ViewerMsg PdfViewer.Msg
    | ListMsg PL.Msg
    | PdfDocMsg PD.Msg
    | EVMsg EV.Msg
    | ServerResponse (Result Http.Error PI.ServerResponse)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( ViewerMsg vm, Viewer mod ) ->
            case PdfViewer.update vm mod of
                PdfViewer.Viewer vmod ->
                    ( { model | page = Viewer vmod }, Cmd.none )

                PdfViewer.List listmodel ->
                    ( { model | page = List listmodel }, Cmd.none )

        ( ListMsg lm, List mod ) ->
            case PL.update lm mod of
                PL.List nmod ->
                    ( { model | page = List nmod }, Cmd.none )

                PL.ListCmd nmod lcmd ->
                    ( { model | page = List nmod }, Cmd.map ListMsg lcmd )

                PL.Viewer vmod ->
                    ( { model | page = Viewer vmod }, Cmd.none )

                PL.Error e ->
                    ( { model | page = ErrorView <| EV.init e (List mod) }, Cmd.none )

        ( PdfDocMsg pdm, page ) ->
            ( model, Cmd.none )

        ( ServerResponse sr, _ ) ->
            case sr of
                Err e ->
                    ( model, Cmd.none )

                Ok isr ->
                    case isr of
                        PI.ServerError e ->
                            ( model, Cmd.none )

                        PI.FileListReceived lst ->
                            ( { model | page = List (PL.init lst model.location) }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )



{- let
       plm =
           model.listModel
   in
   ( { model
       | listModel =
           { plm | pdfs = lst }
     }
   , Cmd.none
   )

-}


view : Model -> Html Msg
view model =
    E.layout
        []
    <|
        case model.page of
            List mod ->
                E.map ListMsg <|
                    PL.view mod

            Viewer mod ->
                E.map ViewerMsg <|
                    PdfViewer.view mod

            Loading ->
                E.text "loading"

            ErrorView evm ->
                E.map EVMsg <| EV.view evm


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
    ( { location = flags.location
      , page = Loading
      }
    , mkPublicHttpReq flags.location PI.GetFileList
    )


main : Program Flags Model Msg
main =
    B.element
        { init = init
        , subscriptions = \_ -> Sub.map PdfDocMsg PD.pdfreceive
        , view = view
        , update = update
        }
