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
import PdfDoc as PD
import PdfInfo exposing (PdfInfo, PdfOpened, PersistentState)
import PdfViewer as PV
import PublicInterface as PI exposing (mkPublicHttpReq)
import Time
import Util as U


type Transition
    = List Model
    | ListCmd Model (Cmd Msg)
    | Viewer (PV.Model Model)
    | OpenDialog Model
    | Error String


type SortColumn
    = Date
    | Name
    | Progress


type Msg
    = Noop
    | OpenClick PdfInfo
    | NewClick
    | PDMsg PD.Msg
    | SortClick SortColumn
    | UpdatePState PersistentState
    | ServerResponse (Result Http.Error PI.ServerResponse)


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


progressColor : E.Color
progressColor =
    E.rgb 0.5 0.5 0.5


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


addPdf : Model -> PdfInfo -> Model
addPdf model pi =
    sort
        { model
            | pdfs =
                pi
                    :: model.pdfs
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
    let
        progress =
            \pi ->
                pi.state
                    |> Maybe.map
                        (\state ->
                            toFloat state.page / toFloat state.pageCount
                        )
                    |> Maybe.withDefault 0
    in
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

                ( Progress, Down ) ->
                    List.sortBy progress model.pdfs
                        |> List.reverse

                ( Progress, Up ) ->
                    List.sortBy progress model.pdfs
    }


init : List PdfInfo -> String -> Maybe String -> ( Model, Cmd Msg )
init pdfs location mbpdfname =
    let
        model =
            sort
                { pdfs = pdfs
                , location = location
                , sortColumn = Date
                , sortDirection = Down
                , opdf = Nothing
                , notes = Nothing
                }
    in
    ( model
    , mbpdfname
        |> Maybe.map (openPdfCmd model)
        |> Maybe.withDefault Cmd.none
    )


openPdfCmd : Model -> String -> Cmd Msg
openPdfCmd model pdfname =
    Cmd.batch
        [ Cmd.map
            PDMsg
          <|
            PD.openPdfUrl
                pdfname
                (model.location ++ "/pdfs/" ++ pdfname)
        , mkPublicHttpReq model.location (PI.GetNotes pdfname) ServerResponse
        ]


view : Model -> Element Msg
view model =
    E.table [ E.width E.fill, E.spacing 5 ]
        { data = model.pdfs
        , columns =
            [ { header =
                    EI.button buttonStyle
                        { label = E.text "new"
                        , onPress = Just <| NewClick
                        }
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
            , { header =
                    EI.button buttonStyle
                        { label = E.text "progress"
                        , onPress = Just <| SortClick Progress
                        }
              , width = E.px 100
              , view =
                    \pi ->
                        case pi.state of
                            Just state ->
                                E.row
                                    [ E.width <| E.px 100
                                    , EB.color progressColor
                                    , EB.width 1
                                    ]
                                    [ E.row
                                        [ E.width <|
                                            E.px <|
                                                round <|
                                                    ((toFloat state.page * 100)
                                                        / toFloat state.pageCount
                                                    )
                                        , EBg.color progressColor
                                        ]
                                        [ E.text "" ]
                                    , E.row [ E.width E.fill ] []
                                    ]

                            Nothing ->
                                E.none
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

                        PI.LastStateReceived _ ->
                            Error "Unexpected last state message"

                        PI.NotesResponse mbnotes ->
                            checkOpen { model | notes = Just mbnotes }

                        PI.PdfStateSaved ->
                            List model

                        PI.Noop ->
                            List model

                        PI.NewPdfSaved pi ->
                            List <|
                                sort
                                    { model
                                        | pdfs =
                                            pi
                                                :: model.pdfs
                                    }

        NewClick ->
            OpenDialog model

        OpenClick pi ->
            let
                nm =
                    { model | notes = Nothing, opdf = Nothing }
            in
            ListCmd nm <|
                openPdfCmd nm pi.fileName

        SortClick column ->
            if column == model.sortColumn then
                List <| sort { model | sortDirection = flipDirection model.sortDirection }

            else
                List <| sort { model | sortColumn = column, sortDirection = Down }

        UpdatePState pstate ->
            List (updateState model pstate)
