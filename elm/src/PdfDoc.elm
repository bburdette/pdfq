port module PdfDoc exposing (..)

import File exposing (File)
import File.Select as FS
import Json.Decode as JD
import Json.Encode as JE
import PdfElement
import Task


port sendPdfCommand : JE.Value -> Cmd msg


pdfsend : PdfElement.PdfCmd -> Cmd Msg
pdfsend =
    PdfElement.send sendPdfCommand


port receivePdfMsg : (JD.Value -> msg) -> Sub msg


pdfreceive : Sub Msg
pdfreceive =
    receivePdfMsg <| PdfElement.receive PdfMsg


type Msg
    = PdfFileOpened File
    | PdfMsg (Result JD.Error PdfElement.PdfMsg)
    | PdfExtracted String String


type alias OpenedPdf =
    { pdfName : String
    , pageCount : Int
    }


type Ret
    = Pdf OpenedPdf
    | Command (Cmd Msg)
    | Error String


{-| open a pdf from url
-}
openPdfUrl : String -> String -> Cmd Msg
openPdfUrl name url =
    pdfsend <| PdfElement.OpenUrl { name = name, url = url }


{-| prompt the user to select a pdf file.
-}
openPdfFile : Cmd Msg
openPdfFile =
    FS.file [ "application/pdf" ] PdfFileOpened


{-| get a pdf from the server.
-}
update : Msg -> Ret
update msg =
    case msg of
        PdfFileOpened file ->
            Command <|
                Task.perform
                    (PdfExtracted (File.name file))
                    (File.toUrl file)

        PdfExtracted name string ->
            case String.split "base64," string of
                [ _, b ] ->
                    Command <| pdfsend <| PdfElement.OpenString { name = name, string = b }

                _ ->
                    Error "file extraction failed"

        PdfMsg ms ->
            case ms of
                Ok (PdfElement.Loaded lm) ->
                    Pdf
                        { pdfName = lm.name
                        , pageCount = lm.pageCount
                        }

                Ok (PdfElement.Error e) ->
                    Error e.error

                Err e ->
                    Error (JD.errorToString e)
