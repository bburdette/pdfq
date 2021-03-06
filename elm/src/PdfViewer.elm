module PdfViewer exposing (..)

import Browser.Dom as Dom
import Common exposing (buttonStyle)
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Events as EE
import Element.Font as EF
import Element.Input as EI
import Html exposing (Html)
import Html.Attributes as HA
import PdfDoc as PD
import PdfElement
import PdfInfo exposing (PdfNotes, PersistentState)
import Task
import Time
import Util


type Transition listmodel
    = Viewer (Model listmodel) Command
      -- | ViewerPersist (Model listmodel) (Time.Posix -> PersistentState)
      -- | ViewerSaveNotes (Model listmodel) PdfNotes
    | List listmodel (Time.Posix -> PersistentState) PdfNotes
    | Sizer (Model listmodel) Int


type Msg
    = SelectClick
    | PrevPage
    | NextPage
    | OnKeyDown String
    | ZoomChanged String
    | PageChanged String
    | NoteChanged String
    | TextFocus Bool
    | StartSizing
    | Noop


type Command
    = CmdPersist (Time.Posix -> PersistentState)
    | CmdSaveNotes PdfNotes
    | CmdCmd (Cmd Msg)
    | CmdBatch (List Command)
    | CmdNoop


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
    , notesWidth : Int
    }


toPersistentState : Model a -> Time.Posix -> PersistentState
toPersistentState model time =
    { pdfName = model.pdfName
    , zoom = model.zoom
    , page = model.page
    , pageCount = model.pageCount
    , lastRead = time
    , notesWidth = model.notesWidth
    }


persist : Model a -> Transition a
persist model =
    Viewer model (CmdPersist <| toPersistentState model)


init : Maybe PersistentState -> Maybe PdfNotes -> PD.OpenedPdf -> a -> Model a
init mbps mbpdfn opdf listmod =
    let
        izoom =
            mbps |> Maybe.map .zoom |> Maybe.withDefault 1.0

        page =
            mbps |> Maybe.map .page |> Maybe.withDefault 1

        nw =
            mbps |> Maybe.map .notesWidth |> Maybe.withDefault 400

        pdfn =
            mbpdfn
                |> Maybe.withDefault
                    { pdfName = opdf.pdfName
                    , notes = ""
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
    , notesWidth = max nw 25
    }


jumpToBottom : String -> Cmd Msg
jumpToBottom id =
    Dom.getViewportOf id
        |> Task.andThen (\info -> Dom.setViewportOf id 0 info.scene.height)
        |> Task.attempt (\_ -> Noop)


jumpToTop : String -> Cmd Msg
jumpToTop id =
    Dom.getViewportOf id
        |> Task.andThen (\info -> Dom.setViewportOf id 0 0)
        |> Task.attempt (\_ -> Noop)


changePage : Int -> Model a -> Transition a
changePage increment model =
    let
        p =
            model.page + increment
    in
    if 0 < p && p <= model.pageCount then
        Viewer { model | page = p, pageText = String.fromInt p } <|
            CmdBatch
                [ CmdCmd
                    (if increment > 0 then
                        jumpToTop "pdfcolumn"

                     else
                        jumpToBottom "pdfcolumn"
                    )
                , CmdPersist <| toPersistentState model
                ]

    else
        Viewer model CmdNoop


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
        CmdNoop


setNotesWidth : Int -> Model a -> Transition a
setNotesWidth w model =
    persist { model | notesWidth = max w 25 }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        SelectClick ->
            List model.listModel (toPersistentState model) model.notes

        OnKeyDown key ->
            if model.textFocus then
                Viewer model CmdNoop

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
                        Viewer model CmdNoop

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
            Viewer { model | notes = updnotes } <| CmdSaveNotes updnotes

        TextFocus focus ->
            Viewer { model | textFocus = focus } CmdNoop

        StartSizing ->
            Sizer model model.notesWidth

        Noop ->
            Viewer model CmdNoop


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
        [ E.width <| E.px model.notesWidth
        , EBg.color <| E.rgb 0.4 0.4 0.4
        , E.spacing 10
        , E.alignTop
        , E.height E.fill
        ]
        [ E.row [ E.width E.fill, E.height E.fill, E.spacing 5 ]
            [ Util.scrollbarYEl
                [ E.padding 10
                ]
              <|
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
            , E.column
                [ E.width <| E.px 5
                , E.height E.fill
                , EBg.color <| E.rgb 0.75 0.75 0.75
                , EE.onMouseDown StartSizing
                ]
                []
            ]
        ]


view : Model a -> Html Msg
view model =
    E.layout
        [ E.height E.fill
        , E.width E.fill
        ]
    <|
        eview model


eview : Model a -> Element Msg
eview model =
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
                , E.htmlAttribute <| HA.id "pdfcolumn"
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
