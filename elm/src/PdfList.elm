module PdfList exposing (..)

import Calendar as CA
import Common exposing (buttonStyle)
import DateTime as DT
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import Json.Decode as JD
import Json.Encode as JE
import PdfDoc as PD
import PdfViewer as PV
import Time
import Util as U


type Transition
    = List Model
    | ListCmd Model (Cmd Msg)
    | Viewer (PV.Model Model)
    | Error String


type alias Model =
    { pdfs : List PdfInfo
    , location : String
    }


init : List PdfInfo -> String -> Model
init pdfs location =
    { pdfs = pdfs
    , location = location
    }


type alias PdfInfo =
    { lastRead : Time.Posix
    , fileName : String
    }


decodePdfInfo : JD.Decoder PdfInfo
decodePdfInfo =
    JD.map2 PdfInfo
        (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))
        (JD.field "filename" JD.string)


decodePdfList : JD.Decoder (List PdfInfo)
decodePdfList =
    JD.field "pdfs" (JD.list decodePdfInfo)


type Msg
    = Noop
    | OpenClick PdfInfo
    | PDMsg PD.Msg


view : Model -> Element Msg
view model =
    E.table [ E.width E.fill, E.spacing 5 ]
        { data = model.pdfs
        , columns =
            [ { header = E.text ""
              , width = E.shrink
              , view =
                    \pi ->
                        EI.button buttonStyle
                            { label = E.text "open"
                            , onPress = Just <| OpenClick pi
                            }
              }
            , { header = E.text "Last Read"
              , width = E.shrink
              , view =
                    \pi ->
                        E.text <| U.dateToString (CA.fromPosix pi.lastRead)
              }
            , { header = E.text "Name"
              , width = E.fill
              , view =
                    \pi ->
                        E.text pi.fileName
              }
            ]
        }


update : Msg -> Model -> Transition
update msg model =
    case msg of
        Noop ->
            List model

        PDMsg pm ->
            case PD.update pm of
                PD.Pdf openedpdf ->
                    Viewer (PV.init openedpdf model)

                PD.Command cmd ->
                    ListCmd model (Cmd.map PDMsg cmd)

                PD.Error e ->
                    Error e

        OpenClick pi ->
            ListCmd model <|
                Cmd.map
                    PDMsg
                <|
                    PD.openPdfUrl
                        pi.fileName
                        (model.location ++ "/pdfs/" ++ pi.fileName)
