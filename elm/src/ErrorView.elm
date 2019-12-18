module ErrorView exposing (..)

import Common as C
import Element as E exposing (Element)
import Element.Input as EI


type Transition a
    = ErrorView (Model a)
    | Back a


type alias Model a =
    { error : String
    , prevState : a
    }


type Msg
    = Noop
    | Okay


init : String -> a -> Model a
init error prevState =
    { error = error
    , prevState = prevState
    }


view : Model a -> Element Msg
view model =
    E.column []
        [ E.text model.error
        , EI.button C.buttonStyle { label = E.text "okay", onPress = Just Okay }
        ]


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        Noop ->
            ErrorView model

        Okay ->
            Back model.prevState
