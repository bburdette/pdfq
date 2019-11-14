module PdfViewer exposing (..)

import Common exposing (buttonStyle)
import Dict
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import Html exposing (Html)
import PdfDoc as PD
import PdfElement
import PdfInfo exposing (PdfNotes, PersistentState, encodePersistentState)
import Process
import PublicInterface as PI
import Task
import Time


type Transition listmodel
    = Viewer (Model listmodel)
    | ViewerPersist (Model listmodel) (Time.Posix -> PersistentState)
    | ViewerSaveNotes (Model listmodel) PdfNotes
    | List listmodel (Time.Posix -> PersistentState)


type Msg
    = SelectClick
    | PrevPage
    | NextPage
    | ZoomChanged String
    | NoteChanged String


type alias Model listmodel =
    { pdfName : String
    , zoom : Float
    , zoomText : String
    , page : Int
    , pageCount : Int
    , listModel : listmodel -- we come from the List, and we return to the list.  I guess?
    , notes : PdfNotes
    }



{-

   model
     |> get .notes
       (\notes ->
         { model | notes = { notes | notes = { "edited " ++ notes.notes } } }

   get = identity

-}


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
        zoom =
            mbps |> Maybe.map .zoom |> Maybe.withDefault 1.0

        page =
            mbps |> Maybe.map .page |> Maybe.withDefault 1

        pdfn =
            mbpdfn
                |> Maybe.withDefault
                    { pdfName = opdf.pdfName
                    , notes = ""
                    , pageNotes = Dict.fromList []
                    }
    in
    { pdfName = opdf.pdfName
    , zoom = zoom
    , zoomText = String.fromFloat zoom
    , page = page
    , pageCount = opdf.pageCount
    , listModel = listmod
    , notes = pdfn
    }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        SelectClick ->
            List model.listModel (toPersistentState model)

        ZoomChanged string ->
            persist
                { model
                    | zoomText = string
                    , zoom = String.toFloat string |> Maybe.withDefault model.zoom
                }

        PrevPage ->
            if model.page > 1 then
                persist { model | page = model.page - 1 }

            else
                Viewer model

        NextPage ->
            if model.page < model.pageCount then
                persist { model | page = model.page + 1 }

            else
                Viewer model

        NoteChanged txt ->
            let
                notes =
                    model.notes

                updnotes =
                    { notes | notes = txt }
            in
            ViewerSaveNotes { model | notes = updnotes } updnotes


topBar : Model a -> Element Msg
topBar model =
    E.row [ E.width E.fill, EBg.color <| E.rgb 0.4 0.4 0.4, E.spacing 5, E.paddingXY 5 5 ]
        [ EI.button buttonStyle { label = E.text "select pdf", onPress = Just SelectClick }
        , E.el [ E.width E.shrink ] <|
            EI.text [ E.width <| E.px 100 ]
                { onChange = ZoomChanged
                , text = model.zoomText
                , placeholder = Nothing
                , label = EI.labelLeft [ EF.color <| E.rgb 1 1 1, E.centerY ] <| E.text "zoom"
                }
        , E.row [ E.height E.fill, E.width E.fill, E.clipX ]
            [ E.el [ E.centerX, EB.color <| E.rgb 0 0 0 ] <| E.text model.pdfName ]
        , E.row [ E.alignRight, E.spacing 5 ]
            [ E.el [ EF.color <| E.rgb 1 1 1 ] <|
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
        [ E.width <| E.px 300
        , EBg.color <| E.rgb 0.4 0.4 0.4
        , E.spacing 10
        , E.padding 10
        , E.scrollbarY
        , E.alignTop
        , E.height <| E.fill
        ]
        [ EI.multiline [ E.alignTop, E.scrollbarY ]
            { onChange = NoteChanged
            , text = model.notes.notes
            , placeholder = Nothing
            , label = EI.labelAbove [ E.alignTop ] <| E.text "notes"
            , spellcheck = True
            }
        ]


view : Model a -> Html Msg
view model =
    E.layout
        [ E.inFront <|
            E.column []
                [ E.el [ E.transparent True ] <| topBar model -- just for spacing!
                , notePanel model
                ]
        , E.inFront <| topBar model
        ]
    <|
        E.column [ E.spacing 5, E.width E.fill, E.alignTop, E.height E.fill ]
            [ E.el [ E.transparent True ] <| topBar model -- just for spacing!
            , E.row [ E.width E.fill, E.alignTop ]
                [ E.el [ E.transparent True ] <| notePanel model
                , E.column [ E.height E.fill, E.width E.fill, E.alignTop ]
                    [ E.column
                        [ E.width E.fill
                        , E.alignTop
                        , E.paddingXY 0 0
                        , E.height E.shrink
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
            ]
