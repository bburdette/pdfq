module Main exposing (..)

import Browser as B
import Element as E
import ErrorView as EV
import Html exposing (Html)
import Http
import PdfDoc as PD
import PdfInfo
import PdfList as PL
import PdfViewer
import PublicInterface as PI
import Task
import Time
import Util


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
    | PDMsg PD.Msg
    | EVMsg EV.Msg
    | Naiow (Time.Posix -> Cmd Msg) Time.Posix
    | ServerResponse (Result Http.Error PI.ServerResponse)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( ViewerMsg vm, Viewer mod ) ->
            case PdfViewer.update vm mod of
                PdfViewer.Viewer vmod ->
                    ( { model | page = Viewer vmod }, Cmd.none )

                PdfViewer.ViewerPersist vmod mkpersist ->
                    ( { model | page = Viewer vmod }
                    , Task.perform
                        (Naiow (\time -> mkPublicHttpReq model.location (PI.SavePdfState (PdfInfo.encodePersistentState (mkpersist time)))))
                        Time.now
                    )

                PdfViewer.List listmodel mkpstate ->
                    ( { model | page = List listmodel }
                    , Time.now
                        |> Task.perform (\time -> ListMsg (PL.UpdatePState (mkpstate time)))
                    )

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

        ( EVMsg evm, ErrorView evmod ) ->
            case EV.update evm evmod of
                EV.ErrorView mod ->
                    ( { model | page = ErrorView mod }, Cmd.none )

                EV.Back pp ->
                    ( { model | page = pp }, Cmd.none )

        ( PDMsg pdm, page ) ->
            -- route PDMsgs to the list model if its active.
            case page of
                List _ ->
                    update (ListMsg (PL.PDMsg pdm)) model

                _ ->
                    ( model, Cmd.none )

        ( ServerResponse sr, page ) ->
            case sr of
                Err e ->
                    ( { model | page = ErrorView <| EV.init (Util.httpErrorString e) page }, Cmd.none )

                Ok isr ->
                    case isr of
                        PI.ServerError e ->
                            ( { model | page = ErrorView <| EV.init e page }, Cmd.none )

                        PI.FileListReceived lst ->
                            ( { model | page = List (PL.init lst model.location) }, Cmd.none )

                        PI.PdfStateSaved ->
                            ( model, Cmd.none )

        ( Naiow mkCmd time, _ ) ->
            ( model, mkCmd time )

        ( _, _ ) ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    case model.page of
        List mod ->
            E.layout
                []
            <|
                E.map ListMsg <|
                    PL.view mod

        Viewer mod ->
            Html.map ViewerMsg <|
                PdfViewer.view mod

        Loading ->
            E.layout
                []
            <|
                E.text "loading"

        ErrorView evm ->
            E.layout
                []
            <|
                E.map EVMsg <|
                    EV.view evm


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
        , subscriptions = \_ -> Sub.map PDMsg PD.pdfreceive
        , view = view
        , update = update
        }
