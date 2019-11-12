module PublicInterface exposing (..)

import Json.Decode as JD
import Json.Encode as JE
import PdfInfo


type SendMsg
    = GetFileList
    | SavePdfState JE.Value


type ServerResponse
    = ServerError String
    | FileListReceived (List PdfInfo.PdfInfo)
    | PdfStateSaved


encodeSendMsg : SendMsg -> JE.Value
encodeSendMsg sm =
    case sm of
        GetFileList ->
            JE.object
                [ ( "what", JE.string "getfilelist" )
                , ( "data", JE.null )
                ]

        SavePdfState state ->
            JE.object
                [ ( "what", JE.string "savepdfstate" )
                , ( "data", state )
                ]


decodeServerResponse : JD.Decoder ServerResponse
decodeServerResponse =
    JD.at [ "what" ] JD.string
        |> JD.andThen
            (\what ->
                case what of
                    "filelist" ->
                        JD.map FileListReceived
                            (JD.field "content"
                                PdfInfo.decodePdfList
                            )

                    "pdfstatesaved" ->
                        JD.succeed PdfStateSaved

                    wat ->
                        JD.succeed
                            (ServerError ("invalid 'what' from server: " ++ wat))
            )
