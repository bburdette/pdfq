module Util exposing (..)

import Array exposing (Array)
import Calendar as CA
import Clock as CL exposing (Time)
import DateTime as DT
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
import Element.Font as Font
import Element.Input as Input
import Http
import Json.Decode as JD
import Json.Encode as JE
import Time exposing (Posix)
import Time.Extra as TE


type alias Size =
    { width : Int
    , height : Int
    }


maxInt : Int
maxInt =
    9007199254740991


minInt : Int
minInt =
    -9007199254740991


deleteArrayElt : Int -> Array a -> Array a
deleteArrayElt idx array =
    Array.toIndexedList array
        |> List.filter (\( i, v ) -> i /= idx)
        |> List.map Tuple.second
        |> Array.fromList


httpErrorString : Http.Error -> String
httpErrorString e =
    case e of
        Http.BadUrl str ->
            "bad url" ++ str

        Http.Timeout ->
            "timeout"

        Http.NetworkError ->
            "network error"

        Http.BadStatus x ->
            "bad status: " ++ String.fromInt x

        Http.BadBody s ->
            "bad body\nstring: " ++ s


rest : List a -> List a
rest list =
    case List.tail list of
        Nothing ->
            []

        Just elts ->
            elts


{-| retrieve a value from a certain position in the list.
for situations where performance isn't important,
like 5 things in the list, and you don't look things up often
-}
listGet : Int -> List a -> Maybe a
listGet idx lst =
    if idx == 0 then
        List.head lst

    else if idx > 0 then
        case List.tail lst of
            Just t ->
                listGet (idx - 1) t

            Nothing ->
                Nothing

    else
        Nothing


{-| set a value in a list. If idx is less than zero, the new item goes to the list head.
if idx is greater than the list length, its appended to the end.
if its in between, it replaces the list value.
-}
listSet : Int -> a -> List a -> List a
listSet idx item lst =
    List.take idx lst
        ++ [ item ]
        ++ List.drop (idx + 1) lst


listDelete : Int -> List a -> List a
listDelete idx lst =
    List.take idx lst
        ++ List.drop (idx + 1) lst


first : (a -> Maybe b) -> List a -> Maybe b
first f l =
    case List.head l of
        Just e ->
            case f e of
                Just x ->
                    Just x

                Nothing ->
                    first f (rest l)

        Nothing ->
            Nothing


trueforany : (a -> Bool) -> List a -> Bool
trueforany f l =
    case List.head l of
        Just e ->
            if f e then
                True

            else
                trueforany f (rest l)

        Nothing ->
            False


mbAsList : Maybe a -> List a
mbAsList mba =
    case mba of
        Just a ->
            [ a ]

        _ ->
            []


mbAndErr : Maybe b -> Maybe b -> Maybe b
mbAndErr mb1 mb2 =
    case mb2 of
        Just v2 ->
            Just v2

        Nothing ->
            case mb1 of
                Just v1 ->
                    Just v1

                Nothing ->
                    Nothing


mblist : List (Maybe a) -> Maybe (List a)
mblist mbs =
    Maybe.map List.reverse <|
        List.foldl
            (\mba mblst ->
                case mblst of
                    Nothing ->
                        Nothing

                    Just lst ->
                        case mba of
                            Nothing ->
                                Nothing

                            Just a ->
                                Just <| a :: lst
            )
            (Just [])
            mbs


rslist : List (Result a b) -> Result a (List b)
rslist rslts =
    Result.map List.reverse <|
        List.foldl
            (\mba rslst ->
                case rslst of
                    Err e ->
                        Err e

                    Ok lst ->
                        case mba of
                            Err e ->
                                Err e

                            Ok a ->
                                Ok <| a :: lst
            )
            (Ok [])
            rslts


intToMonth : Int -> Maybe Time.Month
intToMonth i =
    case i of
        1 ->
            Just Time.Jan

        2 ->
            Just Time.Feb

        3 ->
            Just Time.Mar

        4 ->
            Just Time.Apr

        5 ->
            Just Time.May

        6 ->
            Just Time.Jun

        7 ->
            Just Time.Jul

        8 ->
            Just Time.Aug

        9 ->
            Just Time.Sep

        10 ->
            Just Time.Oct

        11 ->
            Just Time.Nov

        12 ->
            Just Time.Dec

        _ ->
            Nothing


monthToInt : Time.Month -> Int
monthToInt month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


encodeDate : CA.Date -> JE.Value
encodeDate date =
    JE.object
        [ ( "year", JE.int <| CA.getYear date )
        , ( "month", JE.int <| CA.monthToInt <| CA.getMonth date )
        , ( "day", JE.int <| CA.getDay date )
        ]


decodeMonth : JD.Decoder Time.Month
decodeMonth =
    JD.int
        |> JD.andThen
            (\i ->
                case intToMonth i of
                    Just m ->
                        JD.succeed m

                    Nothing ->
                        JD.fail ("invalid month: " ++ String.fromInt i)
            )


decodeDate : JD.Decoder (Maybe CA.Date)
decodeDate =
    JD.map CA.fromRawParts <|
        JD.map3 CA.RawDate
            (JD.field "year" JD.int)
            (JD.field "month" decodeMonth)
            (JD.field "day" JD.int)


encodeTime : CL.Time -> JE.Value
encodeTime time =
    JE.object
        [ ( "h", JE.int <| CL.getHours time )
        , ( "m", JE.int <| CL.getMinutes time )
        , ( "s", JE.int <| CL.getSeconds time )
        , ( "ms", JE.int <| CL.getMilliseconds time )
        ]


decodeTime : JD.Decoder (Maybe CL.Time)
decodeTime =
    JD.map CL.fromRawParts <|
        JD.map4 CL.RawTime
            (JD.field "h" JD.int)
            (JD.field "m" JD.int)
            (JD.field "s" JD.int)
            (JD.field "ms" JD.int)


dateToString : CA.Date -> String
dateToString date =
    String.fromInt (CA.getYear date)
        ++ "-"
        ++ String.fromInt
            (CA.monthToInt <| CA.getMonth date)
        ++ "-"
        ++ String.fromInt
            (CA.getDay date)


stringToDate : String -> Maybe CA.Date
stringToDate s =
    case String.split "-" s of
        [ sy, sm, sd ] ->
            case ( String.toInt sy, Maybe.andThen intToMonth <| String.toInt sm, String.toInt sd ) of
                ( Just y, Just m, Just d ) ->
                    CA.fromRawParts { year = y, month = m, day = d }

                _ ->
                    Nothing

        _ ->
            Nothing


timeToEditString : Time -> String
timeToEditString time =
    (String.padLeft 2 '0' <| String.fromInt <| CL.getHours time)
        ++ ":"
        ++ (String.padLeft 2 '0' <| String.fromInt <| CL.getMinutes time)


timeToString : Time -> String
timeToString time =
    let
        militaryhours =
            CL.getHours time

        am =
            militaryhours < 12

        hours =
            if militaryhours < 13 then
                militaryhours

            else
                militaryhours - 12
    in
    (String.padLeft 2 '0' <| String.fromInt <| hours)
        ++ ":"
        ++ (String.padLeft 2 '0' <| String.fromInt <| CL.getMinutes time)
        ++ " "
        ++ (if am then
                "am"

            else
                "pm"
           )


stringToTime : String -> Maybe Time
stringToTime ts =
    let
        s =
            String.trim ts
    in
    case String.split ":" s of
        [ l, r ] ->
            case ( String.toInt l, String.toInt r ) of
                ( Just h, Just m ) ->
                    CL.fromRawParts { hours = h, minutes = m, seconds = 0, milliseconds = 0 }

                _ ->
                    Nothing

        _ ->
            Nothing


posixDateTimeString : Posix -> String
posixDateTimeString posix =
    DT.fromPosix posix
        |> (\dt -> (dateToString <| DT.getDate dt) ++ " " ++ (timeToString <| DT.getTime dt))


convertToZone : Posix -> Time.Zone -> Time.Zone -> Posix
convertToZone time fromZone toZone =
    let
        fromMins =
            TE.toOffset fromZone time

        toMins =
            TE.toOffset toZone time
    in
    TE.add TE.Minute (toMins - fromMins) toZone time



{- deadEndsToString : List P.DeadEnd -> String
   deadEndsToString deadEnds =
       String.concat (List.intersperse "; " (List.map deadEndToString deadEnds))


   deadEndToString : P.DeadEnd -> String
   deadEndToString deadend =
       problemToString deadend.problem ++ " at row " ++ String.fromInt deadend.row ++ ", col " ++ String.fromInt deadend.col


   problemToString : P.Problem -> String
   problemToString p =
       case p of
           Expecting s ->
               "expecting '" ++ s ++ "'"

           ExpectingInt ->
               "expecting int"

           ExpectingHex ->
               "expecting octal"

           ExpectingOctal ->
               "expecting octal"

           ExpectingBinary ->
               "expecting binary"

           ExpectingFloat ->
               "expecting number"

           ExpectingNumber ->
               "expecting variable"

           ExpectingVariable ->
               "expecting variable"

           ExpectingSymbol s ->
               "expecting symbol '" ++ s ++ "'"

           ExpectingKeyword s ->
               "expecting keyword '" ++ s ++ "'"

           ExpectingEnd ->
               "expecting end"

           UnexpectedChar ->
               "unexpected char"

           Problem s ->
               "problem " ++ s

           BadRepeat ->
               "bad repeat"

-}


jdAndMap : JD.Decoder a -> JD.Decoder (a -> b) -> JD.Decoder b
jdAndMap jda jdb =
    JD.map2 (|>)
        jda
        jdb


const : b -> (a -> b)
const b =
    \_ -> b
