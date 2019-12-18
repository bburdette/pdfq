module Main exposing (..)

import Browser as B
import Browser.Events as BE
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
import PdfViewer as PV
import Process
import PublicInterface as PI exposing (mkPublicHttpReq)
import Sizer as S
import Task
import Time
import Util


type Page
    = Viewer (PV.Model PL.Model)
    | List PL.Model
    | OpenDialog (OD.Model PL.Model)
    | Loading (Maybe LastState)
    | ErrorView (EV.Model Page)
    | Sizer (S.Model Page)


type alias Model =
    { location : String
    , page : Page
    , saveNotes : Dict String ( Int, PdfNotes )
    , saveNotesCount : Int
    , width : Int
    , height : Int
    }


type Msg
    = ViewerMsg PV.Msg
    | ListMsg PL.Msg
    | OpenDialogMsg OD.Msg
    | PDMsg PD.Msg
    | EVMsg EV.Msg
    | SMsg S.Msg
    | Now (Time.Posix -> Cmd Msg) Time.Posix
    | ServerResponse (Result Http.Error PI.ServerResponse)
    | SaveNote String Int
    | OnKeyDown String
    | OnResize Int Int


decodeKey : JD.Decoder String
decodeKey =
    JD.field "key" JD.string


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( ViewerMsg vm, Viewer mod ) ->
            case PV.update vm mod of
                PV.Viewer vmod ->
                    ( { model | page = Viewer vmod }, Cmd.none )

                PV.ViewerPersist vmod mkpersist ->
                    ( { model | page = Viewer vmod }
                    , Task.perform
                        (Now (\time -> mkPublicHttpReq model.location (PI.SavePdfState (PdfInfo.encodePersistentState (mkpersist time))) ServerResponse))
                        Time.now
                    )

                PV.ViewerSaveNotes vmod notes ->
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

                PV.List listmodel mkpstate ->
                    addLastStateCmd
                        ( { model | page = List listmodel }
                        , Time.now
                            |> Task.perform (\time -> ListMsg (PL.UpdatePState (mkpstate time)))
                        )

                PV.Sizer vmod w ->
                    ( { model
                        | page =
                            Sizer
                                (S.init model.width
                                    model.height
                                    w
                                    (Viewer vmod)
                                    (\md ->
                                        case md of
                                            Viewer vmd ->
                                                PV.eview vmd
                                                    |> E.map (\_ -> ())

                                            _ ->
                                                E.none
                                    )
                                )
                      }
                    , Cmd.none
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
                                (OD.init model.location
                                    nlm
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
                        Just pdfinfo ->
                            ( { model | page = List (PL.addPdf dm pdfinfo) }, Cmd.none )

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

        ( SMsg sm, Sizer smod ) ->
            case S.update sm smod of
                S.Sizer nsm ->
                    ( { model | page = Sizer nsm }, Cmd.none )

                S.Return pm i ->
                    let
                        npm =
                            case pm of
                                Viewer vm ->
                                    Viewer <| PV.setNotesWidth i vm

                                _ ->
                                    pm
                    in
                    ( { model | page = npm }, Cmd.none )

                S.Error nsmod errstring ->
                    ( { model | page = ErrorView <| EV.init errstring (Sizer nsmod) }, Cmd.none )

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
                                    , mkPublicHttpReq model.location PI.GetFileList ServerResponse
                                    )

                                _ ->
                                    ( model, Cmd.none )

                        PI.NotesResponse _ ->
                            ( { model | page = ErrorView <| EV.init "unexpected notes message" page }, Cmd.none )

                        PI.PdfStateSaved ->
                            ( model, Cmd.none )

                        PI.Noop ->
                            ( model, Cmd.none )

                        PI.NewPdfSaved pi ->
                            -- ignoring in this context!
                            ( model, Cmd.none )

        ( Now mkCmd time, _ ) ->
            ( model, mkCmd time )

        ( OnKeyDown ks, _ ) ->
            -- let
            --     _ =
            --         Debug.log "key: " ks
            -- in
            update (ViewerMsg (PV.OnKeyDown ks)) model

        ( OnResize w h, pg ) ->
            let
                _ =
                    Debug.log "wH" ( w, h )

                nm =
                    { model | width = w, height = h }
            in
            case pg of
                Sizer s ->
                    ( { nm | page = Sizer (S.updateDims w h s) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( SaveNote pdfname count, _ ) ->
            case Dict.get pdfname model.saveNotes of
                Just ( dictcount, pdfnotes ) ->
                    if dictcount == count then
                        -- timer expired without additional user input.  send the save msg.
                        ( model, mkPublicHttpReq model.location (PI.SaveNotes pdfnotes) ServerResponse )

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
                PV.view mod

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

        Sizer sm ->
            Html.map SMsg <|
                S.view sm


type alias Flags =
    { location : String
    , width : Int
    , height : Int
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { location = flags.location
      , page = Loading Nothing
      , saveNotes = Dict.empty
      , saveNotesCount = 0
      , width = flags.width
      , height = flags.height
      }
    , mkPublicHttpReq flags.location PI.GetLastState ServerResponse
    )


main : Program Flags Model Msg
main =
    B.element
        { init = init
        , subscriptions =
            \_ ->
                Sub.batch
                    [ Sub.map PDMsg PD.pdfreceive
                    , BE.onKeyDown (JD.map OnKeyDown decodeKey)
                    , BE.onResize OnResize
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
                    mkPublicHttpReq model.location (PI.SaveLastState ls) ServerResponse
                )
            |> Maybe.withDefault Cmd.none
        ]
    )
