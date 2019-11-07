module Main exposing (..)

import Browser as B
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
import PdfElement
import PdfList
import PdfViewer
import Task


type alias Model =
    { viewerModel : PdfViewer.Model
    }


type Msg
    = ViewerMsg PdfViewer.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ViewerMsg vm ->
            let
                ( vmod, vcmd ) =
                    PdfViewer.update vm model.viewerModel
            in
            ( { model | viewerModel = vmod }, Cmd.map ViewerMsg vcmd )


view : Model -> Html Msg
view model =
    E.layout
        []
    <|
        E.map ViewerMsg <|
            PdfViewer.view model.viewerModel


type alias Flags =
    ()


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { viewerModel = PdfViewer.init }
    , Cmd.none
    )


main : Program Flags Model Msg
main =
    B.element
        { init = init
        , subscriptions = \_ -> Sub.map ViewerMsg PdfViewer.pdfreceive
        , view = view
        , update = update
        }
