suppressPackageStartupMessages({
  library(httpuv)
  library(jsonlite)
})

env <- new.env(parent = globalenv())

object_path <- Sys.getenv("R_SESSION_OBJECT_PATH", "data/object.qs")
object_name <- Sys.getenv("R_SESSION_OBJECT_NAME", "obj")
skip_load <- identical(Sys.getenv("R_SESSION_SKIP_LOAD", "0"), "1")

load_object <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "qs") {
    if (!requireNamespace("qs", quietly = TRUE)) {
      stop("R package 'qs' is required for .qs files")
    }
    return(qs::qread(path))
  }
  if (extension == "rds") {
    return(readRDS(path))
  }
  stop(sprintf("unsupported object file extension for '%s'; add a loader in load_object()", path))
}

if (skip_load) {
  message("Skipping object load because R_SESSION_SKIP_LOAD=1")
} else {
  if (!file.exists(object_path)) {
    stop(sprintf("object file not found: %s", object_path))
  }
  message(sprintf("Loading object once from %s ...", object_path))
  assign(object_name, load_object(object_path), envir = env)
  message(sprintf("Loaded object as: %s", object_name))
}

env$.persistent_session <- list(
  object_path = object_path,
  object_name = object_name,
  loaded = !skip_load
)

session_status <- function() {
  list(
    ok = TRUE,
    object_path = env$.persistent_session$object_path,
    object_name = env$.persistent_session$object_name,
    loaded = env$.persistent_session$loaded,
    objects = ls(envir = env)
  )
}

run_code <- function(code) {
  if (is.raw(code)) {
    code <- rawToChar(code)
  }
  if (is.null(code) || !nzchar(code)) {
    return(list(ok = FALSE, output = "", messages = "", warnings = "", error = "empty request body"))
  }

  error_msg <- NULL
  warning_msg <- character()
  message_msg <- character()

  output <- capture.output({
    tryCatch(
      withCallingHandlers(
        {
          con <- textConnection(code)
          on.exit(close(con), add = TRUE)
          source(con, local = env, keep.source = TRUE)
        },
        warning = function(w) {
          warning_msg <<- c(warning_msg, conditionMessage(w))
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          message_msg <<- c(message_msg, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      ),
      error = function(e) {
        error_msg <<- conditionMessage(e)
      }
    )
  })

  list(
    ok = is.null(error_msg),
    output = paste(output, collapse = "\n"),
    messages = paste(message_msg, collapse = "\n"),
    warnings = paste(warning_msg, collapse = "\n"),
    error = error_msg
  )
}

json_response <- function(payload, status = 200L) {
  list(
    status = status,
    headers = c("Content-Type" = "application/json"),
    body = jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
  )
}

read_request_body <- function(req) {
  input <- req$rook.input
  if (is.null(input)) {
    return("")
  }
  rawToChar(input$read())
}

make_app <- function() {
  list(
    call = function(req) {
      method <- req$REQUEST_METHOD
      path <- req$PATH_INFO

      if (identical(method, "GET") && identical(path, "/status")) {
        return(json_response(session_status()))
      }

      if (identical(method, "POST") && identical(path, "/run")) {
        result <- run_code(read_request_body(req))
        status <- if (isTRUE(result$ok)) 200L else 400L
        return(json_response(result, status = status))
      }

      json_response(list(ok = FALSE, error = "not found"), status = 404L)
    }
  )
}

host <- Sys.getenv("R_SESSION_HOST", "127.0.0.1")
port <- as.integer(Sys.getenv("R_SESSION_PORT", "8787"))
if (is.na(port)) {
  stop("R_SESSION_PORT must be an integer")
}

server <- httpuv::startServer(host, port, make_app())
on.exit(httpuv::stopServer(server), add = TRUE)
message(sprintf("Persistent R session listening on http://%s:%s", host, port))
while (TRUE) {
  httpuv::service()
  Sys.sleep(0.01)
}
