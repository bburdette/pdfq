module Sizer exposing (..)

import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Events as EE
import Element.Font as EF
import Element.Input as EI
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Http
import Json.Decode as JD
import Svg exposing (Attribute, Svg, g, rect, svg, text)
import Svg.Attributes exposing (..)
import Svg.Events exposing (onClick, onMouseDown, onMouseOut, onMouseUp)
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
            let
                _ =
                    Debug.log "MM: " (getLocation model v)
            in
            case getLocation model v of
                Ok l ->
                    let
                        _ =
                            Debug.log "l: " l
                    in
                    Sizer { model | position = l }

                Err e ->
                    let
                        _ =
                            Debug.log "mmerr: " e
                    in
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

        -- , EE.onMouseMove MouseMoved
        , EE.onMouseUp MouseUp

        -- , EE.onClick Cancel
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
    let
        _ =
            Debug.log "svide: " ( model.windowWidth, model.windowHeight )
    in
    g
        [ onMouseMove
        , width (String.fromInt model.windowWidth)
        , height (String.fromInt model.windowHeight)
        ]
        [ rect
            [ x "0"
            , y "0"
            , width (String.fromInt model.windowWidth)
            , height (String.fromInt model.windowHeight)
            , rx "2"
            , ry "2"
            , style "fill: #00000000;"
            ]
            []
        , rect
            -- [ x "50"
            [ x (String.fromInt model.position)
            , y "0"
            , width "5"
            , height (String.fromInt model.windowHeight)
            , rx "2"
            , ry "2"
            , style "fill: #FF0000;"
            ]
            []
        ]


onMouseMove =
    sliderEvt "mousemove" MouseMoved


sliderEvt : String -> (JD.Value -> Msg) -> VD.Attribute Msg
sliderEvt evtname mkmsg =
    -- VD.onWithOptions evtname (VD.Options True True) (JD.map (\v -> mkmsg v) JD.value)
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
