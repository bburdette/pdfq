module PublicInterface exposing (..)

import Json.Decode as JD
import Json.Encode as JE
import PdfInfo exposing (LastState(..))


type SendMsg
    = GetFileList
    | SavePdfState JE.Value
    | GetNotes String
    | SaveNotes PdfInfo.PdfNotes
    | SaveLastState LastState
    | GetLastState


type ServerResponse
    = ServerError String
    | FileListReceived (List PdfInfo.PdfInfo)
    | NotesResponse (Maybe PdfInfo.PdfNotes)
    | PdfStateSaved
    | LastStateReceived LastState
    | Noop


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

        GetNotes pdfName ->
            JE.object
                [ ( "what", JE.string "getnotes" )
                , ( "data", JE.string pdfName )
                ]

        SaveNotes pdfNotes ->
            JE.object
                [ ( "what", JE.string "savenotes" )
                , ( "data", PdfInfo.encodePdfNotes pdfNotes )
                ]

        SaveLastState lstate ->
            JE.object
                [ ( "what", JE.string "savelaststate" )
                , ( "data", PdfInfo.encodeLastState lstate )
                ]

        GetLastState ->
            JE.object
                [ ( "what", JE.string "getlaststate" )
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
                                PdfInfo.decodePdfList
                            )

                    "laststate" ->
                        let
                            _ =
                                Debug.log "laststaet:" "decode"
                        in
                        JD.map LastStateReceived
                            (JD.field "content"
                                PdfInfo.decodeLastState
                            )

                    "laststatesaved" ->
                        JD.succeed Noop

                    "pdfstatesaved" ->
                        JD.succeed PdfStateSaved

                    "notesresponse" ->
                        JD.map NotesResponse
                            (JD.maybe
                                (JD.field "content"
                                    PdfInfo.decodePdfNotes
                                )
                            )

                    "notesaved" ->
                        JD.succeed Noop

                    "notesavefailed" ->
                        JD.succeed
                            (ServerError "note save failed!")

                    "server error" ->
                        JD.map ServerError
                            (JD.field "content" JD.string |> JD.map (\s -> "server error: " ++ s))

                    wat ->
                        JD.succeed
                            (ServerError ("invalid 'what' from server: " ++ wat))
            )
