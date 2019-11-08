port module PdfViewer exposing (..)

import Common exposing (buttonStyle)
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import File exposing (File)
import File.Select as FS
import Json.Decode as JD
import Json.Encode as JE
import PdfElement
import PdfList
import Task


port sendPdfCommand : JE.Value -> Cmd msg


pdfsend : PdfElement.PdfCmd -> Cmd Msg
pdfsend =
    PdfElement.send sendPdfCommand


port receivePdfMsg : (JD.Value -> msg) -> Sub msg


pdfreceive : Sub Msg
pdfreceive =
    receivePdfMsg <| PdfElement.receive PdfMsg


type alias Model =
    { pdfName : Maybe String
    , zoom : Float
    , zoomText : String
    , page : Int
    , pageCount : Maybe Int
    }


type Msg
    = OpenClick
    | PrevPage
    | NextPage
    | PdfOpened File
    | ZoomChanged String
    | PdfExtracted String String
    | PdfMsg (Result JD.Error PdfElement.PdfMsg)


openPdfUrl : String -> String -> Cmd Msg
openPdfUrl name url =
    pdfsend <| PdfElement.OpenUrl { name = name, url = url }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OpenClick ->
            ( model, FS.file [ "application/pdf" ] PdfOpened )

        PdfOpened file ->
            ( model, Task.perform (PdfExtracted (File.name file)) (File.toUrl file) )

        PdfExtracted name string ->
            case String.split "base64," string of
                [ _, b ] ->
                    ( { model | page = 1 }, pdfsend <| PdfElement.OpenString { name = name, string = b } )

                _ ->
                    ( model, Cmd.none )

        ZoomChanged string ->
            ( { model
                | zoomText = string
                , zoom = String.toFloat string |> Maybe.withDefault model.zoom
              }
            , Cmd.none
            )

        PdfMsg ms ->
            let
                _ =
                    Debug.log "pm" ms
            in
            case ms of
                Ok (PdfElement.Loaded lm) ->
                    ( { model
                        | pdfName = Just lm.name
                        , pageCount = Just lm.pageCount
                      }
                    , Cmd.none
                    )

                Ok (PdfElement.Error e) ->
                    let
                        _ =
                            Debug.log "pdfee" e
                    in
                    ( model, Cmd.none )

                Err e ->
                    let
                        _ =
                            Debug.log "erree" e
                    in
                    ( model, Cmd.none )

        PrevPage ->
            if model.page > 1 then
                ( { model | page = model.page - 1 }, Cmd.none )

            else
                ( model, Cmd.none )

        NextPage ->
            case model.pageCount of
                Just pc ->
                    if model.page < pc then
                        ( { model | page = model.page + 1 }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )


topBar : Model -> Element Msg
topBar model =
    E.row [ E.width E.fill, EBg.color <| E.rgb 0.4 0.4 0.4, E.spacing 5, E.paddingXY 5 5 ]
        [ EI.button buttonStyle { label = E.text "open pdf", onPress = Just OpenClick }
        , E.el [ E.width E.shrink ] <|
            EI.text [ E.width <| E.px 100 ]
                { onChange = ZoomChanged
                , text = model.zoomText
                , placeholder = Nothing
                , label = EI.labelLeft [ EF.color <| E.rgb 1 1 1, E.centerY ] <| E.text "zoom"
                }
        , case model.pdfName of
            Just name ->
                E.row [ E.height E.fill, E.width E.fill, E.clipX ] [ E.el [ E.centerX, EB.color <| E.rgb 0 0 0 ] <| E.text name ]

            Nothing ->
                E.none
        , E.row [ E.alignRight, E.spacing 5 ]
            [ E.el [ EF.color <| E.rgb 1 1 1 ] <|
                E.text <|
                    "Page: "
                        ++ String.fromInt model.page
                        ++ " of "
                        ++ (model.pageCount
                                |> Maybe.map String.fromInt
                                |> Maybe.withDefault "?"
                           )
            , EI.button buttonStyle { label = E.text "prev", onPress = Just PrevPage }
            , EI.button buttonStyle { label = E.text "next", onPress = Just NextPage }
            ]
        ]


view : Model -> Element Msg
view model =
    E.column [ E.spacing 5, E.width E.fill, E.alignTop, E.inFront <| topBar model ]
        [ E.el [ E.transparent True ] <| topBar model
        , case model.pdfName of
            Just name ->
                E.row [ E.width E.fill, E.alignTop ]
                    [ E.column
                        [ E.width E.fill
                        , E.height E.fill
                        , E.alignTop
                        , E.paddingXY 5 0
                        ]
                        [ E.el
                            [ E.width E.shrink
                            , E.centerX
                            , EB.width 5
                            , E.alignTop
                            ]
                          <|
                            E.html <|
                                PdfElement.pdfPage name model.page (PdfElement.Scale model.zoom)
                        ]
                    ]

            Nothing ->
                E.none
        ]


init : Model
init =
    { pdfName = Nothing
    , zoom = 1.0
    , zoomText = "1.0"
    , page = 1
    , pageCount = Nothing
    }
