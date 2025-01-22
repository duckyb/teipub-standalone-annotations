This document outlines our current objective for the project.

# Milestone 1 - Standalone Annotations API

Our objective with this milestone is to allow our frontend to attach annotations to a standalone document.
With "standalone" we mean a document that is NOT stored on exist-db, but rather it is passed to the API as base64 encoded content or URL.

## Problems we encountered

We have discovered that some of the default functions of the annotations API do not work for standalone documents.
As a workaround, we will try to save the document to a temporary location in exist-db and then apply the annotations to it.

## Debugging steps

1. Save the uploaded document to exist-db.
2. Get the document from an URL and load it with `doc(url)`
3. Try loading the document with `form-data` and `doc(base64)`
