module PdfViewer exposing (..)

import Common exposing (buttonStyle)
import Dict
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Events as EE
import Element.Font as EF
import Element.Input as EI
import Html exposing (Html)
import PdfDoc as PD
import PdfElement
import PdfInfo exposing (PdfNotes, PersistentState)
import Time
import Util


type Transition listmodel
    = Viewer (Model listmodel)
    | ViewerPersist (Model listmodel) (Time.Posix -> PersistentState)
    | ViewerSaveNotes (Model listmodel) PdfNotes
    | List listmodel (Time.Posix -> PersistentState)


type Msg
    = SelectClick
    | PrevPage
    | NextPage
    | OnKeyDown String
    | ZoomChanged String
    | PageChanged String
    | NoteChanged String
    | TextFocus Bool


type alias Model listmodel =
    { pdfName : String
    , zoom : Float
    , zoomText : String
    , page : Int
    , pageText : String
    , pageCount : Int
    , listModel : listmodel
    , notes : PdfNotes
    , textFocus : Bool
    }


toPersistentState : Model a -> Time.Posix -> PersistentState
toPersistentState model time =
    { pdfName = model.pdfName
    , zoom = model.zoom
    , page = model.page
    , pageCount = model.pageCount
    , lastRead = time
    }


persist : Model a -> Transition a
persist model =
    ViewerPersist model (toPersistentState model)


init : Maybe PersistentState -> Maybe PdfNotes -> PD.OpenedPdf -> a -> Model a
init mbps mbpdfn opdf listmod =
    let
        izoom =
            mbps |> Maybe.map .zoom |> Maybe.withDefault 1.0

        page =
            mbps |> Maybe.map .page |> Maybe.withDefault 1

        pdfn =
            mbpdfn
                |> Maybe.withDefault
                    { pdfName = opdf.pdfName
                    , notes = ""

                    -- , pageNotes = Dict.fromList []
                    }
    in
    { pdfName = opdf.pdfName
    , zoom = izoom
    , zoomText = String.fromFloat izoom
    , page = page
    , pageText = String.fromInt page
    , pageCount = opdf.pageCount
    , listModel = listmod
    , notes = pdfn
    , textFocus = False
    }


changePage : Int -> Model a -> Transition a
changePage increment model =
    let
        p =
            model.page + increment
    in
    if 0 < p && p < model.pageCount then
        persist { model | page = p, pageText = String.fromInt p }

    else
        Viewer model


zoom : Float -> Model a -> Transition a
zoom mult model =
    let
        z =
            model.zoom * mult
    in
    Viewer
        { model
            | zoom = z
            , zoomText = String.fromFloat z
        }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        SelectClick ->
            List model.listModel (toPersistentState model)

        OnKeyDown key ->
            if model.textFocus then
                Viewer model

            else
                case key of
                    "ArrowRight" ->
                        changePage 1 model

                    "ArrowLeft" ->
                        changePage -1 model

                    "PageDown" ->
                        changePage 1 model

                    "PageUp" ->
                        changePage -1 model

                    "+" ->
                        zoom 1.1 model

                    "=" ->
                        zoom 1.1 model

                    "-" ->
                        zoom (1.0 / 1.1) model

                    "_" ->
                        zoom (1.0 / 1.1) model

                    _ ->
                        Viewer model

        ZoomChanged string ->
            persist
                { model
                    | zoomText = string
                    , zoom = String.toFloat string |> Maybe.withDefault model.zoom
                }

        PageChanged string ->
            persist
                { model
                    | pageText = string
                    , page = String.toInt string |> Maybe.withDefault model.page
                }

        PrevPage ->
            changePage -1 model

        NextPage ->
            changePage 1 model

        NoteChanged txt ->
            let
                notes =
                    model.notes

                updnotes =
                    { notes | notes = txt }
            in
            ViewerSaveNotes { model | notes = updnotes } updnotes

        TextFocus focus ->
            Viewer { model | textFocus = focus }


topBar : Model a -> Element Msg
topBar model =
    E.row [ E.width E.fill, EBg.color <| E.rgb 0.4 0.4 0.4, E.spacing 5, E.paddingXY 5 5 ]
        [ EI.button buttonStyle { label = E.text "select pdf", onPress = Just SelectClick }
        , E.el [ E.width E.shrink ] <|
            EI.text
                [ E.width <| E.px 100
                , EE.onFocus <| TextFocus True
                , EE.onLoseFocus <| TextFocus False
                ]
                { onChange = ZoomChanged
                , text = model.zoomText
                , placeholder = Nothing
                , label = EI.labelLeft [ EF.color <| E.rgb 1 1 1, E.centerY ] <| E.text "zoom"
                }
        , E.row [ E.height E.fill, E.width E.fill, E.clipX ]
            [ E.el [ E.centerX, EB.color <| E.rgb 0 0 0 ] <| E.text model.pdfName ]
        , E.row [ E.alignRight, E.spacing 5 ]
            [ E.el [ E.width E.shrink ] <|
                EI.text
                    [ E.width <| E.px 100
                    , EE.onFocus <| TextFocus True
                    , EE.onLoseFocus <| TextFocus False
                    ]
                    { onChange = PageChanged
                    , text = model.pageText
                    , placeholder = Nothing
                    , label = EI.labelHidden "page"
                    }
            , E.el [ EF.color <| E.rgb 1 1 1 ] <|
                E.text <|
                    "Page: "
                        ++ String.fromInt model.page
                        ++ " of "
                        ++ String.fromInt model.pageCount
            , EI.button buttonStyle { label = E.text "prev", onPress = Just PrevPage }
            , EI.button buttonStyle { label = E.text "next", onPress = Just NextPage }
            ]
        ]


notePanel : Model a -> Element Msg
notePanel model =
    E.column
        [ E.width <| E.px 400
        , EBg.color <| E.rgb 0.4 0.4 0.4
        , E.spacing 10
        , E.padding 10
        , E.alignTop
        , E.height E.fill
        ]
        [ Util.scrollbarYEl [] <|
            EI.multiline
                [ E.alignTop
                , EE.onFocus <| TextFocus True
                , EE.onLoseFocus <| TextFocus False
                ]
                { onChange = NoteChanged
                , text = model.notes.notes
                , placeholder = Nothing
                , label = EI.labelHidden "notes"
                , spellcheck = True
                }
        ]


view : Model a -> Html Msg
view model =
    E.layout
        [ E.height E.fill
        , E.width E.fill
        ]
    <|
        E.column
            [ E.width E.fill
            , E.height E.fill
            ]
            [ topBar model
            , E.row [ E.width E.fill, E.height E.fill, E.scrollbarY ]
                [ notePanel model
                , E.column
                    [ E.width E.fill
                    , E.alignTop
                    , E.paddingXY 0 0
                    , E.height E.fill
                    , E.scrollbarY
                    ]
                    [ E.el
                        [ E.width E.shrink
                        , E.centerX
                        , EB.width 3
                        , E.alignTop
                        ]
                      <|
                        E.html <|
                            PdfElement.pdfPage model.pdfName model.page (PdfElement.Scale model.zoom)
                    ]
                ]
            ]
