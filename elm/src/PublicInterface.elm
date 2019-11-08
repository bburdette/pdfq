module PublicInterface exposing (..)

import Json.Decode as JD
import Json.Encode as JE
import PdfList


type SendMsg
    = GetFileList


type ServerResponse
    = ServerError String
    | FileListReceived PdfList.PdfList



-- | FileListReceived (Result JD.Error PdfList.PdfList)


encodeSendMsg : SendMsg -> JE.Value
encodeSendMsg sm =
    case sm of
        GetFileList ->
            JE.object
                [ ( "what", JE.string "getfilelist" )
                , ( "data", JE.null )
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
                                PdfList.decodePdfList
                            )

                    wat ->
                        JD.succeed
                            (ServerError ("invalid 'what' from server: " ++ wat))
            )
