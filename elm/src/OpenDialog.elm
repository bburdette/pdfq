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
import PdfInfo as PdI exposing (PdfNotes, PersistentState)
import PublicInterface as PI exposing (mkPublicHttpReq)
import Task
import Time
import Url
import Util


type Transition prevmodel
    = Dialog (Model prevmodel)
    | DialogCmd (Model prevmodel) (Cmd Msg)
    | Return prevmodel (Maybe PdI.PdfOpened)
    | Error (Model prevmodel) String


type Msg
    = FileClick
    | UrlClick
    | UrlChanged String
    | NameChanged String
    | PdfOpened File.File
    | PdfUrlOpened (Result Http.Error String)
    | PdfOpTime (Result String PdI.PdfOpened)
    | ServerResponse (Result Http.Error PI.ServerResponse)
    | Cancel
    | Noop


type alias Model prevmodel =
    { pdfUrl : String
    , pdfName : String
    , prevModel : prevmodel
    , prevRender : prevmodel -> Element ()
    , location : String
    }


init : String -> a -> (a -> Element ()) -> Model a
init location prevmod render =
    { pdfUrl = ""
    , pdfName = ""
    , prevModel = prevmod
    , prevRender = render
    , location = location
    }


update : Msg -> Model a -> Transition a
update msg model =
    case msg of
        FileClick ->
            DialogCmd model (FS.file [ "application/pdf" ] PdfOpened)

        UrlClick ->
            -- cors won't allow it!  download on the server instead.
            DialogCmd model
                (mkPublicHttpReq model.location
                    (PI.GetPdf
                        { pdfName = model.pdfName
                        , pdfUrl = model.pdfUrl
                        }
                    )
                    ServerResponse
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
                                                    Ok <| PdI.PdfOpened (File.name file) b now
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
                    let
                        _ =
                            Debug.log "PD.PdfUrlOpened : " str
                    in
                    Dialog model

        -- (Task.perform PdfOpTime
        --     (Time.now
        --         |> Task.map (\x -> Ok <| PdI.PdfOpened model.pdfUrl (B64.encode str) x)
        --     )
        -- )
        PdfOpTime pdfopened ->
            case pdfopened of
                Ok po ->
                    Return model.prevModel (Just po)

                Err e ->
                    Error model e

        UrlChanged urlstr ->
            let
                name =
                    Url.fromString urlstr
                        |> Maybe.andThen
                            (\url ->
                                String.split "/" url.path
                                    |> List.head
                                    << List.reverse
                            )
                        |> Maybe.withDefault model.pdfName
            in
            Dialog { model | pdfUrl = urlstr, pdfName = name }

        NameChanged name ->
            Dialog { model | pdfName = name }

        Noop ->
            Dialog model

        Cancel ->
            Return model.prevModel Nothing

        ServerResponse _ ->
            Dialog model


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
        , if model.pdfUrl == "" then
            E.none

          else
            EI.text
                []
                { onChange = NameChanged
                , text = model.pdfName
                , placeholder = Nothing
                , label =
                    EI.labelLeft [ E.centerY ] <| E.text "name"
                }
        , EI.button buttonStyle { label = E.text "open file", onPress = Just FileClick }
        ]
