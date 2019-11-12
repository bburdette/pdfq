module PdfViewer exposing (..)

-- import PdfList as PL

import Common exposing (buttonStyle)
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import File exposing (File)
import File.Select as FS
import Html exposing (Html)
import Json.Decode as JD
import Json.Encode as JE
import PdfDoc as PD
import PdfElement
import Task


type Transition listmodel
    = Viewer (Model listmodel)
    | List listmodel


type alias Model listmodel =
    { pdfName : String
    , zoom : Float
    , zoomText : String
    , page : Int
    , pageCount : Int
    , listModel : listmodel -- we come from the List, and we return to the list.  I guess?
    }


type alias PersistentState =
    { pdfName : String
    , zoom : Float
    , page : Int
    }


init : PD.OpenedPdf -> a -> Model a
init opdf listmod =
    { pdfName = opdf.pdfName
    , zoom = 1.0
    , zoomText = "1.0"
    , page = 1
    , pageCount = opdf.pageCount
    , listModel = listmod
    }



{- toState : Model -> PersistentState
   toState model =
       { pdfName = model.pdfName
       , zoom = model.zoom
       , page = model.page
       }
-}


type Msg
    = SelectClick
    | PrevPage
    | NextPage
    | ZoomChanged String



{- | OpenClick
   OpenClick ->
       -- uh, new state for the opening of a file?
       -- or, (Transition, Cmd) ?
       Viewer model
-}


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        SelectClick ->
            -- transition back to pdflist state!
            List model.listModel

        ZoomChanged string ->
            Viewer
                { model
                    | zoomText = string
                    , zoom = String.toFloat string |> Maybe.withDefault model.zoom
                }

        PrevPage ->
            if model.page > 1 then
                Viewer { model | page = model.page - 1 }

            else
                Viewer model

        NextPage ->
            if model.page < model.pageCount then
                Viewer { model | page = model.page + 1 }

            else
                Viewer model


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


view : Model a -> Html Msg
view model =
    E.layout
        [ E.inFront <| topBar model ]
    <|
        E.column [ E.spacing 5, E.width E.fill, E.alignTop ]
            [ E.el [ E.transparent True ] <| topBar model
            , E.row [ E.width E.fill, E.alignTop ]
                [ E.column
                    [ E.width E.fill
                    , E.height E.fill
                    , E.alignTop
                    , E.paddingXY 5 0
                    ]
                    [ E.el
                        [ E.width E.shrink
                        , E.centerX
                        , EB.width 5
                        , E.alignTop
                        ]
                      <|
                        E.html <|
                            PdfElement.pdfPage model.pdfName model.page (PdfElement.Scale model.zoom)
                    ]
                ]
            ]



{- init : PersistentState -> Model
   init =
       { pdfName = Nothing
       , zoom = 1.0
       , zoomText = "1.0"
       , page = 1
       , pageCount = Nothing
       }
-}
