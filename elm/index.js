// --------------------------------------------------------
// init elm
// --------------------------------------------------------
import { Elm } from './main.js';

import * as pdfe from "./node_modules/pdf-element/pdfelement.js";
// import * as pdfe from "./pdfelement.js";

var app = Elm.Main.init({
  node: document.querySelector('main'),
  flags: { location : document.location.origin || "",
           width : window.innerWidth, 
           height : window.innerHeight
         }
});

app.ports.sendPdfCommand.subscribe(pdfe.pdfCommandReceiver(app));
