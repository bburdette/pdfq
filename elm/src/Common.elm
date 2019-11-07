module Common exposing (..)

import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI


buttonStyle : List (E.Attribute msg)
buttonStyle =
    [ EBg.color <| E.rgb 0.1 0.1 0.1
    , EF.color <| E.rgb 1 1 0
    , EB.color <| E.rgb 1 0 1
    , E.paddingXY 10 10
    , EB.rounded 3
    ]
