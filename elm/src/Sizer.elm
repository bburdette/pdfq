module Sizer exposing (..)

import Common exposing (buttonStyle)
import Dict
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Events as EE
import Element.Font as EF
import Element.Input as EI
import File
import File.Select as FS
import Html exposing (Html)
import Html.Events as HE
import Http
import Json.Decode as JD
import PdfDoc as PD
import PdfElement
import PdfInfo as PdI exposing (PdfNotes, PersistentState)
import PublicInterface as PI exposing (mkPublicHttpReq)
import Task
import Time
import Url
import Util


type Transition prevmodel
    = Sizer (Model prevmodel)
    | Return prevmodel Int
    | Error (Model prevmodel) String


type Msg
    = MouseUp
    | MouseMoved
    | Noop


type alias Model prevmodel =
    { position : Int
    , start : Int
    , prevModel : prevmodel
    , prevRender : prevmodel -> Element ()
    }


init : Int -> a -> (a -> Element ()) -> Model a
init startpos prevModel render =
    { position = startpos
    , start = startpos
    , prevModel = prevModel
    , prevRender = render
    }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        MouseUp ->
            Return model.prevModel model.position

        MouseMoved ->
            Sizer model

        Noop ->
            Sizer model


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
        , E.inFront E.none

        -- , EE.onClick Cancel
        ]
        []
