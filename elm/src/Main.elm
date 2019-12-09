module Main exposing (..)

import Browser as B
import Browser.Events
import Dict exposing (Dict)
import Element as E
import ErrorView as EV
import Html exposing (Html)
import Http
import Json.Decode as JD
import OpenDialog as OD
import PdfDoc as PD
import PdfInfo exposing (LastState(..), PdfNotes)
import PdfList as PL
import PdfViewer
import Process
import PublicInterface as PI
import Task
import Time
import Util


type Page
    = Viewer (PdfViewer.Model PL.Model)
    | List PL.Model
    | OpenDialog (OD.Model PL.Model)
    | Loading (Maybe LastState)
    | ErrorView (EV.Model Page)


type alias Model =
    { location : String
    , page : Page
    , saveNotes : Dict String ( Int, PdfNotes )
    , saveNotesCount : Int
    }


type Msg
    = ViewerMsg PdfViewer.Msg
    | ListMsg PL.Msg
    | OpenDialogMsg OD.Msg
    | PDMsg PD.Msg
    | EVMsg EV.Msg
    | Now (Time.Posix -> Cmd Msg) Time.Posix
    | ServerResponse (Result Http.Error PI.ServerResponse)
    | SaveNote String Int
    | OnKeyDown String


decodeKey : JD.Decoder String
decodeKey =
    JD.field "key" JD.string


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
                        (Now (\time -> mkPublicHttpReq model.location (PI.SavePdfState (PdfInfo.encodePersistentState (mkpersist time)))))
                        Time.now
                    )

                PdfViewer.ViewerSaveNotes vmod notes ->
                    ( { model
                        | page = Viewer vmod
                        , saveNotes = Dict.insert notes.pdfName ( model.saveNotesCount, notes ) model.saveNotes
                        , saveNotesCount = model.saveNotesCount + 1
                      }
                    , -- N second delay before saving.
                      Process.sleep 5000
                        |> Task.perform
                            (\_ -> SaveNote notes.pdfName model.saveNotesCount)
                    )

                PdfViewer.List listmodel mkpstate ->
                    addLastStateCmd
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

                PL.OpenDialog nlm ->
                    ( { model
                        | page =
                            OpenDialog
                                (OD.init nlm
                                    (\m -> E.map (\_ -> ()) (PL.view m))
                                )
                      }
                    , Cmd.none
                    )

                PL.Viewer vmod ->
                    addLastStateCmd
                        ( { model | page = Viewer vmod }, Cmd.none )

                PL.Error e ->
                    ( { model | page = ErrorView <| EV.init e (List mod) }, Cmd.none )

        ( OpenDialogMsg odm, OpenDialog odmod ) ->
            case OD.update odm odmod of
                OD.Dialog dm ->
                    ( { model | page = OpenDialog dm }, Cmd.none )

                OD.DialogCmd dm cmd ->
                    ( { model | page = OpenDialog dm }, Cmd.map OpenDialogMsg cmd )

                OD.Return dm mbpdfopened ->
                    case mbpdfopened of
                        Just pdfsave ->
                            ( { model | page = List dm }, mkPublicHttpReq model.location (PI.SavePdf pdfsave) )

                        Nothing ->
                            ( { model | page = List dm }, Cmd.none )

                OD.Error dm errstring ->
                    ( { model | page = ErrorView <| EV.init errstring (OpenDialog dm) }, Cmd.none )

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
                            let
                                mbpdfname =
                                    case model.page of
                                        Loading (Just (LsViewer pdfname)) ->
                                            Just pdfname

                                        _ ->
                                            Nothing

                                ( lm, lcmd ) =
                                    PL.init lst model.location mbpdfname
                            in
                            case mbpdfname of
                                Nothing ->
                                    addLastStateCmd
                                        ( { model | page = List lm }
                                        , Cmd.map ListMsg lcmd
                                        )

                                Just _ ->
                                    ( { model | page = List lm }
                                    , Cmd.map ListMsg lcmd
                                    )

                        PI.LastStateReceived ls ->
                            case page of
                                Loading _ ->
                                    ( { model | page = Loading ls }
                                    , mkPublicHttpReq model.location PI.GetFileList
                                    )

                                _ ->
                                    ( model, Cmd.none )

                        PI.NotesResponse _ ->
                            ( { model | page = ErrorView <| EV.init "unexpected notes message" page }, Cmd.none )

                        PI.PdfStateSaved ->
                            ( model, Cmd.none )

                        PI.Noop ->
                            ( model, Cmd.none )

        ( Now mkCmd time, _ ) ->
            ( model, mkCmd time )

        ( OnKeyDown ks, _ ) ->
            -- let
            --     _ =
            --         Debug.log "key: " ks
            -- in
            update (ViewerMsg (PdfViewer.OnKeyDown ks)) model

        ( SaveNote pdfname count, _ ) ->
            case Dict.get pdfname model.saveNotes of
                Just ( dictcount, pdfnotes ) ->
                    if dictcount == count then
                        -- timer expired without additional user input.  send the save msg.
                        ( model, mkPublicHttpReq model.location (PI.SaveNotes pdfnotes) )

                    else
                        -- there's a newer save reminder out there.  wait for that one instead.
                        ( model, Cmd.none )

                Nothing ->
                    -- I guess it got saved already?  Can't save what we don't have I guess.
                    ( model, Cmd.none )

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

        OpenDialog mod ->
            Html.map OpenDialogMsg <|
                OD.view mod

        Loading _ ->
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
      , page = Loading Nothing
      , saveNotes = Dict.empty
      , saveNotesCount = 0
      }
    , mkPublicHttpReq flags.location PI.GetLastState
    )


main : Program Flags Model Msg
main =
    B.element
        { init = init
        , subscriptions =
            \_ ->
                Sub.batch
                    [ Sub.map PDMsg PD.pdfreceive
                    , Browser.Events.onKeyDown (JD.map OnKeyDown decodeKey)
                    ]
        , view = view
        , update = update
        }


toLastState : Model -> Maybe LastState
toLastState model =
    case model.page of
        Viewer vmod ->
            Just <|
                LsViewer vmod.pdfName

        List _ ->
            Just <|
                LsList

        _ ->
            Nothing


addLastStateCmd : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
addLastStateCmd ( model, cmd ) =
    ( model
    , Cmd.batch
        [ cmd
        , toLastState model
            |> Maybe.map
                (\ls ->
                    mkPublicHttpReq model.location (PI.SaveLastState ls)
                )
            |> Maybe.withDefault Cmd.none
        ]
    )
