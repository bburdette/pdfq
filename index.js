// --------------------------------------------------------
// init elm
// --------------------------------------------------------
import { Elm } from './elm/src/Main.elm';

import * as pdfe from "./node_modules/pdf-element/pdfelement.js";
// import * as pdfe from "./pdfelement.js";

var app = Elm.Main.init({
  node: document.querySelector('main'),
  flags: { location : document.location.origin || "" }
});

app.ports.sendPdfCommand.subscribe(pdfe.pdfCommandReceiver(app));
