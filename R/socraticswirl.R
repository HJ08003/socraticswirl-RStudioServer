# This contains functions for uploading exercise results to SocraticSwirl servers.
# But we are not doing that any more as parse.com is no longer active.

#' extract socratic_swirl options from environment
#' 
#' @param error whether to raise an error
#' 
#' @return A list containing
#'   \item{course}{course name for current SocraticSwirl session}
#'   \item{lesson}{lesson name for current SocraticSwirl session}
socratic_swirl_options <- function(error = TRUE) {
  course <- getOption("socratic_swirl_course")
  lesson <- getOption("socratic_swirl_lesson")
  instructor <- getOption("socratic_swirl_instructor")
  exercise <- getOption("socratic_swirl_exercise")
  student <- getOption("socratic_swirl_student")
  isskipped <- getOption("socratic_swirl_isskipped")
  # student <- digest::digest(Sys.info())
  
  if (is.null(course) || is.null(lesson) || is.null(instructor)) {
    if (!error) {
      return(NULL)
    }
    stop("SocraticSwirl is not set up; did you forget to call ",
         "socratic_swirl?")
  }
  
  write_object_StudentSession("StudentSession", course = course, lesson = lesson,
               instructor = instructor, student = student,
               ACL = socratic_swirl_acl())
  
  return(list(course = course, lesson = lesson, instructor = instructor,
              student = student, exercise = exercise, isskipped = isskipped))
}

#' Create an ACL (Access Control List) object for instructor-only objects
#' 
#' Create an ACL preventing anyone but the instructor from seeing the student's
#' response.
socratic_swirl_acl <- function() {
  ID <- getOption("socratic_swirl_instructor_id")
  if (is.null(ID)) {
    stop("SocraticSwirl instructor not set")
  }
  ret <- list()
  ret[[ID]] <- list(read = TRUE)
  ret
}



#' set up SocraticSwirl in this session
#' 
#' Run this to set up a SocraticSwirl lesson. Particular exercises can then
#' be accessed using the \code{\link{exercise}} function.
#' 
#' @param course course name
#' @param lesson lesson name
#' 
#' @export
socratic_swirl <- function(course, lesson) {
    
# For a working version:
# 1. Replace <socraticswirl instructorID> with the username of an instructor
#    registered in the parse.com database.  This must be the same as the username and password
#    used in the dashboard to login to parse.com
# 2. Replace <parse.com application key> and <parse.com API key> with the appropriate parse.com keys

#  if (instance == "test") {
#      Sys.setenv(PARSE_APPLICATION_ID = "<parse.com application key for test application>",
#                 PARSE_API_KEY = "parse.com API key for test application>")
#  } else {
#      Sys.setenv(PARSE_APPLICATION_ID = "<parse.com application key for production application>",
#                 PARSE_API_KEY = "<parse.com API key for production application")
#  }


  # All courses and lessons should be upper case
  course <- toupper(course)
  lesson <- toupper(lesson)
  student <- as.character(Sys.info()["effective_user"])
  instructor <- getOption("SocraticswirlRStudioServer")$Instructor
  instructor_user <- list(objectId = "1234567")

  message("Installing course ", course)

  # Install the course directly from the file system
  install_course_directory(paste0(getOption("SocraticswirlRStudioServer")$CourseFolder, "/", course))
  
  # check that lesson exists in the directory
  course_name <- stringr::str_replace_all(course, " ", "_")
  lesson_name <- stringr::str_replace_all(lesson, " ", "_")
  lesson_dir <- file.path(find.package("socraticswirl"), "Courses", course_name, lesson_name)
  
  if (!file.exists(lesson_dir)) {
    stop("Lesson '", lesson, "' not found in course '", course, "'")
  }

  # set course and lesson name options
  options(socratic_swirl_course = course,
          socratic_swirl_lesson = lesson,
          socratic_swirl_instructor = instructor,
          socratic_swirl_student = student,
          socratic_swirl_instructor_id = instructor_user$objectId,
          socratic_swirl_isskipped = FALSE)
  
  # set up error function
  options(error = socratic_swirl_error)

}


#' Function called after an error during a SocraticSwirl attempt
socratic_swirl_error <- function() {
  err_message <- geterrmessage()
  
  # save, read, then delete a history
  savehistory(file = ".hist")
  command <- stringr::str_trim(tail(readLines(".hist"), 1))
  unlink(".hist")
  
  opts <- socratic_swirl_options(error = FALSE)
  if (is.null(opts)) {
    return(NULL)
  }
 
  ret <- write_object_StudentResponse("StudentResponse",
                      course = opts$course,
                      lesson = opts$lesson,
                      exercise = opts$exercise,
                      instructor = opts$instructor,
                      isCorrect = FALSE,
                      command = command,
                      isError = TRUE,
                      errorMsg = err_message,
                      student = opts$student,
                      ACL = socratic_swirl_acl())
}



#' Take an instructor-provided exercise with SocraticSwirl
#' 
#' This is to be called after \code{\link{socratic_swirl}} is used to set up
#' a SocraticSwirl session.
#' 
#' @param exercise Which quiz exercise to take; provided by instructor
#' 
#' @export
exercise <- function(exercise) {
  opts <- socratic_swirl_options()
  
  options(socratic_swirl_exercise = exercise)

  # set up error function
  options(error = socratic_swirl_error)

  swirl("test",
        test_course = opts$course,
        test_lesson = opts$lesson,
        from = exercise,
        to = exercise + .5)
}

#' Take an instructor-provided lesson with SocraticSwirl
#' 
#' This is to be called after \code{\link{socratic_swirl}} is used to set up
#' a SocraticSwirl session.
#' 
#' @param exercise Which quiz exercise to take; provided by instructor
#' 
#' @export

start <- function() {
  opts <- socratic_swirl_options()
  
  # set up error function
  options(error = socratic_swirl_error)

  swirl("test",
        test_course = opts$course,
        test_lesson = opts$lesson)
}


#' Given a Swirl environment, update SocraticSwirl server
#' 
#' @param e Swirl environment, containing info on the current Swirl session
#' @param correct whether the answer was correct
#' 
#' 
#' @return boolean describing whether it uploaded the Socratic Swirl results
notify_socratic_swirl <- function(e, correct = TRUE) {
  o <- socratic_swirl_options(error = FALSE)
  if (is.null(o)) {
    # no socratic swirl set up
    return(FALSE)
  }

  if (o$isskipped) {
      answer = "SKIPPED"
      options(socratic_swirl_isskipped = FALSE)
  } else {
      if (e$current.row$Class[1] == 'mult_question') {
          answer <- e$val
          if ((answer=="") & (correct==FALSE)) {
            e$prompt = TRUE
            return(FALSE)
          }
      } else {
          answer <- paste(str_trim(deparse(e$expr)), collapse = " ")
      }
  }
  
# If needed, dump the option files to find out if o is ok, and if e carries anything at all. 
# Since e is an environment created in swirl(), not sure what's in it. The above e$current_row may at risk too.
  if (FALSE) {
    if (is.null(e$test_course) || is.null(e$test_lesson) || is.na(e$test_course) || is.na(e$test_lesson)) {
      save(e, file=gsub("\\s", "", paste0("e-", date())))
    }
    if (is.null(o$course) || is.null(o$lesson) || is.na(o$course) || is.na(o$lesson)) {
      save(o, file=gsub("\\s", "", paste0("o-", date())))
    }
  }

# Since o is verified at the begin of this procedure/function, it is safe to use o instead of e which is questionable.

   ret <- write_object_StudentResponse("StudentResponse",
                      course = o$course,
                      lesson = o$lesson,
                      exercise = o$exercise,  # index of question
                      instructor = o$instructor,
                      isCorrect = correct,
                      isError = FALSE,
                      errorMsg = "",
                      command = answer,
                      student = o$student,
                      ACL = socratic_swirl_acl())


  # print(paste(o$course, o$lesson, o$exercise, o$student, o$instructor, correct, FALSE, answer, socratic_swirl_acl(), sep = "\t"))
  # TODO: check that there wasn't an error communicating with the server
  TRUE
}

set_object_Directory <- function(course, lesson, student) {
  BaseDirectory <- getOption("SocraticswirlRStudioServer")$RecordFolder
  if (! dir.exists(file.path(BaseDirectory, student))) {
    dir.create(file.path(BaseDirectory, student))
  }
  if (! dir.exists(file.path(BaseDirectory, student))) {
    dir.create(file.path(BaseDirectory, student))
  }
  if (! dir.exists(file.path(BaseDirectory, student, course))) {
     dir.create(file.path(BaseDirectory, student, course))
  }
  if (! dir.exists(file.path(BaseDirectory, student, course, lesson))) {
    dir.create(file.path(BaseDirectory, student, course, lesson))
  }
}

write_object_StudentResponse <- function(task, course, lesson, exercise, instructor, isCorrect, isError, errorMsg, command, student, ACL) {
  if (task == "StudentResponse") {
    dt <- date()
    BaseDirectory <- file.path(getOption("SocraticswirlRStudioServer")$RecordFolder, student, course, lesson)
    #
    # \n and \t may cause a problem in data
    errorMsg <- gsub("\t", "{tab}", gsub("\n", "{newline}", errorMsg))
    # command <- gsub("\t", "{tab}", gsub("\n", "{newline}", command))
    #
    a <- c(course, lesson, exercise, student, instructor, dt, isCorrect, isError, command, errorMsg)
    names(a) <- c("Course", "Lesson", "Exercise", "Student", "Instructor", "Date", "isCorrect", "isError", "Command", "ErrorMassage")
    set_object_Directory(course, lesson, student)
    filename <- paste0(paste(task, gsub(" ", ":", dt), sep = "-"), ".tsv")
    write.table(t(a), file = file.path(BaseDirectory, filename), row.names=FALSE, sep="\t", quote = FALSE)
    # print(paste(course, lesson, exercise, student, instructor, date(), isCorrect, isError, command, errorMsg, ACL, sep = "\t"))
  } else {
    stop("Should only work for StudentResponse")
  }
}

write_object_StudentQuestion <- function(task, course, lesson, instructor, student, question, addressed, ACL) {
  if (task == "StudentQuestion") {
    dt <- date()
    BaseDirectory <- file.path(getOption("SocraticswirlRStudioServer")$RecordFolder, student, course, lesson)
    a <- c(course, lesson, student, instructor, dt, question, addressed)
    names(a) <- c("Course", "Lesson", "Student", "Instructor", "Date", "Question", "Addressed")
    set_object_Directory(course, lesson, student)
    filename <- paste0(paste(task, gsub(" ", ":", dt), sep = "-"), ".tsv")
    write.table(t(a), file = file.path(BaseDirectory, filename), row.names=FALSE, sep="\t", quote = FALSE)
    # print(paste(course, lesson, student, instructor, date(), question, addressed, ACL, sep = "\t"))
  } else {
    stop("Should only work for StudentQuestion")
  }
}

write_object_StudentSession <- function(task, course, lesson, instructor, student, ACL) {
  if (task == "StudentSession") {
    dt <- date()
    BaseDirectory <- file.path(getOption("SocraticswirlRStudioServer")$RecordFolder, student, course, lesson)
    a <- c(course, lesson, student, instructor, dt)
    names(a) <- c("Course", "Lesson", "Student", "Instructor", "Date")
    set_object_Directory(course, lesson, student)
    filename <- paste0(paste(task, gsub(" ", ":", dt), sep = "-"), ".tsv")
    write.table(t(a), file = file.path(BaseDirectory, filename), row.names=FALSE, sep="\t", quote = FALSE)
    # print(paste(course, lesson, student, instructor, date(), ACL, sep = "\t"))
  } else {
    stop("Should only work for StudentSession")
  }
}



#' Submit a question to the instructor
#'
#'
#' @param q Question
#' 
#'
#' @export
ask_question <- function(q){
  o <- socratic_swirl_options(error = FALSE)
  if (is.null(o)) {
    # no socratic swirl set up
    return(FALSE)
  }
  ret <- write_object_StudentQuestion("StudentQuestion",
               course = o$course,
               lesson = o$lesson,
               instructor = o$instructor,
               student = o$student,
               question = q,
               addressed = FALSE,
               ACL = socratic_swirl_acl())
}


#' install a course from the Socratic Swirl server
#'
#' Given the title of a course, install it from the server
#'
#' @param course Course title
#' 
#'
#' @export
install_course_socratic_swirl <- function(course) {
  # retrieve course
  co <- parse_query("Course", title = course)
  
  if (length(co) == 0) {
    stop("No course with title ", course, " found")
  }

  # get the first one (there should never be redundant; but just in case)
  install_course_url(co$zipfile$url[1])
}

