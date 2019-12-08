module OpenDialog exposing (..)

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


type Transition prevmodel
    = Dialog (Model prevmodel)
    | Return prevmodel


type Msg
    = FileClick
    | UrlClick
    | UrlChanged String
    | Cancel
    | Noop


type alias Model prevmodel =
    { pdfUrl : String
    , prevModel : prevmodel
    , prevRender : prevmodel -> Element ()
    }


init : a -> (a -> Element ()) -> Model a
init prevmod render =
    { pdfUrl = ""
    , prevModel = prevmod
    , prevRender = render
    }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        FileClick ->
            -- Cmd for file open
            Return model.prevModel

        UrlClick ->
            -- server message for downloading pdf?
            Dialog model

        UrlChanged url ->
            Dialog { model | pdfUrl = url }

        Noop ->
            Dialog model

        Cancel ->
            -- Cmd for file open
            Return model.prevModel


view : Model a -> Html Msg
view model =
    E.layout
        [ E.height E.fill
        , E.width E.fill
        , E.inFront (overlay model)
        ]
        (model.prevRender model.prevModel
            |> E.map (\_ -> Noop)
        )


overlay : Model a -> Element Msg
overlay model =
    E.column
        [ E.height E.fill
        , E.width E.fill
        , EBg.color <| E.rgba 0.5 0.5 0.5 0.5
        , E.inFront (dialogView model)
        , EE.onClick Cancel
        ]
        []


dialogView : Model a -> Element Msg
dialogView model =
    E.column
        [ EB.color <| E.rgb 0 0 0
        , E.centerX
        , E.centerY
        , EB.width 5
        , EBg.color <| E.rgb 1 1 1
        , E.paddingXY 10 10
        , E.spacing 5
        ]
        [ E.row
            [ E.spacing 5 ]
            [ EI.text
                []
                { onChange = UrlChanged
                , text = model.pdfUrl
                , placeholder = Nothing
                , label =
                    EI.labelLeft [ E.centerY ] <|
                        EI.button buttonStyle { label = E.text "open url:", onPress = Just UrlClick }
                }
            ]
        , EI.button buttonStyle { label = E.text "open file", onPress = Just FileClick }
        ]
