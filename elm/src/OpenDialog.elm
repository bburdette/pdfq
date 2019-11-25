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


type alias Model prevmodel =
    { pdfUrl : String
    , prevModel : prevmodel
    }


init : a -> Model a
init prevmod =
    { pdfUrl = ""
    , prevModel = prevmod
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


view : Model a -> Html Msg
view model =
    E.layout
        [ E.height E.fill
        , E.width E.fill
        ]
    <|
        E.column [ E.width E.fill ]
            [ E.row
                [ E.width E.fill
                ]
                [ EI.text
                    []
                    { onChange = UrlChanged
                    , text = model.pdfUrl
                    , placeholder = Nothing
                    , label = EI.labelLeft [ EF.color <| E.rgb 1 1 1, E.centerY ] <| E.text "url"
                    }
                , EI.button buttonStyle { label = E.text "open url", onPress = Just UrlClick }
                ]
            , EI.button buttonStyle { label = E.text "open file", onPress = Just FileClick }
            ]
