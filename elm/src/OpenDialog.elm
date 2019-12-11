module OpenDialog exposing (..)

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
import PdfInfo as PI exposing (PdfNotes, PersistentState)
import Task
import Time
import Util


type Transition prevmodel
    = Dialog (Model prevmodel)
    | DialogCmd (Model prevmodel) (Cmd Msg)
    | Return prevmodel (Maybe PI.PdfOpened)
    | Error (Model prevmodel) String


type Msg
    = FileClick
    | UrlClick
    | UrlChanged String
    | PdfOpened File.File
    | PdfUrlOpened (Result Http.Error String)
    | PdfOpTime (Result String PI.PdfOpened)
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
            DialogCmd model (FS.file [ "application/pdf" ] PdfOpened)

        UrlClick ->
            DialogCmd model
                (Http.get
                    { url = model.pdfUrl
                    , expect = Http.expectString PdfUrlOpened
                    }
                )

        PdfOpened file ->
            DialogCmd model <|
                Task.perform PdfOpTime
                    (File.toUrl file
                        |> Task.andThen
                            (\filestring ->
                                case String.split "base64," filestring of
                                    [ _, b ] ->
                                        Time.now
                                            |> Task.map
                                                (\now ->
                                                    Ok <| PI.PdfOpened (File.name file) b now
                                                )

                                    _ ->
                                        Task.succeed <| Err "file extraction failed"
                            )
                    )

        PdfUrlOpened rs ->
            case rs of
                Err e ->
                    Error model <| Util.httpErrorString e

                Ok str ->
                    DialogCmd model
                        (Task.perform PdfOpTime
                            (Time.now
                                |> Task.map (\x -> Ok <| PI.PdfOpened model.pdfUrl str x)
                            )
                        )

        PdfOpTime pdfopened ->
            case pdfopened of
                Ok po ->
                    Return model.prevModel (Just po)

                Err e ->
                    Error model e

        UrlChanged url ->
            Dialog { model | pdfUrl = url }

        Noop ->
            Dialog model

        Cancel ->
            Return model.prevModel Nothing


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
        , E.htmlAttribute <|
            HE.custom "click"
                (JD.succeed
                    { message = Noop
                    , stopPropagation = True
                    , preventDefault = True
                    }
                )
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
