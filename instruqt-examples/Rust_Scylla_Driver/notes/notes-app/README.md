
Demo Notes application to work on top of Rest Rust API server for Scylla for Notes application

Warning - adding new notes is not implemented yet! (the + button doesn't work!)
Just viewing and scrolling through existing ones works.
Use REST API / postman (sample in rust server) to add new notes.

Developer notes
----------------
Install Node.js
https://nodejs.org/en/download

then install Ionic:
`npm install -g @ionic/cli`

Project itself is very simple and was created using
`ionic start --type=angular notes-app`
(choose list template, then ng modules were chosen, and src/app dir got populated with files)

- Go to your cloned project: cd .\notes-app
- Run `ionic serve` within the app directory to see your app in the browser
- Run `ionic capacitor` add to add a native iOS or Android project using Capacitor
- Generate your app icon and splash screens using `cordova-res --skip-config --copy`
- Explore the Ionic docs for components, tutorials, and more: https://ion.link/docs

To simulate mobile views check
https://ionicframework.com/docs/developing/previewing#simulating-a-mobile-viewport
