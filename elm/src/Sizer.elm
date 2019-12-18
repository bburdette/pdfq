module Sizer exposing (..)

import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Events as EE
import Html exposing (Html)
import Html.Attributes as HA
import Json.Decode as JD
import Svg exposing (Attribute, Svg, g, rect, svg)
import Svg.Attributes as SA
import Svg.Events exposing (onMouseUp)
import VirtualDom as VD


type Transition prevmodel
    = Sizer (Model prevmodel)
    | Return prevmodel Int
    | Error (Model prevmodel) String


type Msg
    = MouseUp
    | MouseMoved JD.Value
    | Noop


type alias Model prevmodel =
    { position : Int
    , start : Int
    , prevModel : prevmodel
    , prevRender : prevmodel -> Element ()
    , windowWidth : Int
    , windowHeight : Int
    }


init : Int -> Int -> Int -> a -> (a -> Element ()) -> Model a
init w h startpos prevModel render =
    { position = startpos
    , start = startpos
    , prevModel = prevModel
    , prevRender = render
    , windowWidth = w
    , windowHeight = h
    }


updateDims : Int -> Int -> Model a -> Model a
updateDims w h model =
    { model | windowWidth = w, windowHeight = h }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        MouseUp ->
            Return model.prevModel model.position

        MouseMoved v ->
            case getLocation model v of
                Ok l ->
                    Sizer { model | position = l + 3 }

                Err e ->
                    Error model e

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
        , EE.onMouseUp MouseUp
        ]
        [ E.html <|
            Svg.svg
                [ HA.width model.windowWidth
                , HA.height model.windowHeight
                ]
                [ sview model ]
        ]


sview : Model a -> Svg Msg
sview model =
    g
        [ onMouseMove
        , SA.width (String.fromInt model.windowWidth)
        , SA.height (String.fromInt model.windowHeight)
        ]
        [ rect
            [ SA.x "0"
            , SA.y "0"
            , SA.width (String.fromInt model.windowWidth)
            , SA.height (String.fromInt model.windowHeight)
            , SA.rx "2"
            , SA.ry "2"
            , SA.style "fill: #00000000;"
            ]
            []
        , rect
            [ SA.x (String.fromInt (model.position - 5))
            , SA.y "0"
            , SA.width "5"
            , SA.height (String.fromInt model.windowHeight)
            , SA.rx "2"
            , SA.ry "2"
            , SA.style "fill: #DFDFDF;"
            ]
            []
        ]


onMouseMove =
    sliderEvt "mousemove" MouseMoved


sliderEvt : String -> (JD.Value -> Msg) -> VD.Attribute Msg
sliderEvt evtname mkmsg =
    VD.on evtname <|
        VD.Custom
            (JD.map
                (\v ->
                    { stopPropagation = True, preventDefault = True, message = mkmsg v }
                )
                JD.value
            )


getLocation : Model a -> JD.Value -> Result String Int
getLocation model v =
    JD.decodeValue getX v
        |> Result.mapError JD.errorToString


getX : JD.Decoder Int
getX =
    JD.field "pageX" JD.int
