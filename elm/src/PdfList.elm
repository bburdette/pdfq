module PdfList exposing (..)

import Calendar as CA
import Common exposing (buttonStyle)
import DateTime as DT
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import Http
import Json.Decode as JD
import Json.Encode as JE
import PdfDoc as PD
import PdfInfo exposing (PdfInfo, PersistentState)
import PdfViewer as PV
import PublicInterface as PI
import Time
import Util as U


type Transition
    = List Model
    | ListCmd Model (Cmd Msg)
    | Viewer (PV.Model Model)
    | Error String


type alias Model =
    { pdfs : List PdfInfo
    , location : String
    , sortColumn : SortColumn
    , sortDirection : SortDirection
    , opdf : Maybe PD.OpenedPdf
    , notes : Maybe (Maybe PdfInfo.PdfNotes) -- 'Just Nothing' indicates no notes on server.
    }


type SortDirection
    = Up
    | Down


updateState : Model -> PersistentState -> Model
updateState model state =
    sort
        { model
            | pdfs =
                List.map
                    (\pi ->
                        if pi.fileName == state.pdfName then
                            { pi
                                | state = Just state
                                , lastRead = state.lastRead
                            }

                        else
                            pi
                    )
                    model.pdfs
        }


flipDirection : SortDirection -> SortDirection
flipDirection dir =
    case dir of
        Up ->
            Down

        Down ->
            Up


sort : Model -> Model
sort model =
    { model
        | pdfs =
            case ( model.sortColumn, model.sortDirection ) of
                ( Date, Down ) ->
                    List.sortBy (.lastRead >> Time.posixToMillis) model.pdfs
                        |> List.reverse

                ( Date, Up ) ->
                    List.sortBy (.lastRead >> Time.posixToMillis) model.pdfs

                ( Name, Down ) ->
                    List.sortBy .fileName model.pdfs
                        |> List.reverse

                ( Name, Up ) ->
                    List.sortBy .fileName model.pdfs
    }


type SortColumn
    = Date
    | Name


init : List PdfInfo -> String -> Model
init pdfs location =
    sort
        { pdfs = pdfs
        , location = location
        , sortColumn = Date
        , sortDirection = Down
        , opdf = Nothing
        , notes = Nothing
        }


type Msg
    = Noop
    | OpenClick PdfInfo
    | PDMsg PD.Msg
    | SortClick SortColumn
    | UpdatePState PersistentState
    | ServerResponse (Result Http.Error PI.ServerResponse)


view : Model -> Element Msg
view model =
    E.table [ E.width E.fill, E.spacing 5 ]
        { data = model.pdfs
        , columns =
            [ { header = E.text ""
              , width = E.shrink
              , view =
                    \pi ->
                        EI.button buttonStyle
                            { label = E.text "open"
                            , onPress = Just <| OpenClick pi
                            }
              }
            , { header =
                    EI.button buttonStyle
                        { label = E.text "last read"
                        , onPress = Just <| SortClick Date
                        }
              , width = E.shrink
              , view =
                    \pi ->
                        E.el [ E.centerY ] <|
                            E.text <|
                                U.dateToString (CA.fromPosix pi.lastRead)
              }
            , { header =
                    EI.button buttonStyle
                        { label = E.text "name"
                        , onPress = Just <| SortClick Name
                        }
              , width = E.fill
              , view =
                    \pi ->
                        E.el [ E.centerY ] <|
                            E.text
                                pi.fileName
              }
            ]
        }


checkOpen : Model -> Transition
checkOpen model =
    case ( model.opdf, model.notes ) of
        ( Just opdf, Just notes ) ->
            let
                state =
                    U.first
                        (\pi ->
                            if pi.fileName == opdf.pdfName then
                                pi.state

                            else
                                Nothing
                        )
                        model.pdfs
            in
            Viewer (PV.init state notes opdf model)

        _ ->
            List model


update : Msg -> Model -> Transition
update msg model =
    case msg of
        Noop ->
            List model

        PDMsg pm ->
            case PD.update pm of
                PD.Pdf openedpdf ->
                    checkOpen { model | opdf = Just openedpdf }

                PD.Command cmd ->
                    ListCmd model (Cmd.map PDMsg cmd)

                PD.Error e ->
                    Error e

        ServerResponse sr ->
            case sr of
                Err e ->
                    Error (U.httpErrorString e)

                Ok isr ->
                    case isr of
                        PI.ServerError e ->
                            Error e

                        PI.FileListReceived _ ->
                            Error "Unexpected file list message"

                        PI.NotesResponse mbnotes ->
                            checkOpen { model | notes = Just mbnotes }

                        PI.PdfStateSaved ->
                            List model

                        PI.Noop ->
                            List model

        OpenClick pi ->
            ListCmd model <|
                Cmd.batch
                    [ Cmd.map
                        PDMsg
                      <|
                        PD.openPdfUrl
                            pi.fileName
                            (model.location ++ "/pdfs/" ++ pi.fileName)
                    , mkPublicHttpReq model.location (PI.GetNotes pi.fileName)
                    ]

        SortClick column ->
            if column == model.sortColumn then
                List <| sort { model | sortDirection = flipDirection model.sortDirection }

            else
                List <| sort { model | sortColumn = column, sortDirection = Down }

        UpdatePState pstate ->
            List (updateState model pstate)


mkPublicHttpReq : String -> PI.SendMsg -> Cmd Msg
mkPublicHttpReq location msg =
    Http.post
        { url = location ++ "/public"
        , body = Http.jsonBody (PI.encodeSendMsg msg)
        , expect = Http.expectJson ServerResponse PI.decodeServerResponse
        }
