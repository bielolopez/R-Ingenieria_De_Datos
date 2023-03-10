# Pipeline

Binarize_Features <- function(data_set, features_to_ignore=c(), leave_out_one_level=FALSE, max_level_count=20) {
  require(dplyr)
  text_features <- c(names(data_set[sapply(data_set, is.character)]), names(data_set[sapply(data_set, is.factor)]))
  for (feature_name in setdiff(text_features, features_to_ignore)) {
    feature_vector <- as.character(data_set[,feature_name])
    # Ver los datos que tiene más de un nivel
    if (length(unique(feature_vector)) == 1)
      next
    # Cambiar los no datos a texto
    feature_vector[is.na(feature_vector)] <- 'NA'
    feature_vector[is.infinite(feature_vector)] <- 'INF'
    feature_vector[is.nan(feature_vector)] <- 'NAN'
    # dejar solo las top N de las categorias más importantes
    temp_vect <- data.frame(table(feature_vector)) %>% arrange(desc(Freq)) %>% head(max_level_count)
    feature_vector <- ifelse(feature_vector %in% temp_vect$feature_vector, feature_vector, 'Other')
    # Crear las nuevas columnas dummy para cada nivel
    first_level=TRUE
    for (newcol in unique(feature_vector)) {
      if (leave_out_one_level & first_level) {
        # remover la primera columna para salir de la trampa de las dummies.
        first_level=FALSE
        next
      }
      data_set[,paste0(feature_name,"_",newcol)] <- ifelse(feature_vector==newcol,1,0)
    }
    # remover la columnas originales.
    data_set <- data_set[,setdiff(names(data_set),feature_name)]
  }
  return (data_set)
}






Get_Free_Text_Measures <- function(data_set, minimum_unique_threshold=0.9, features_to_ignore=c()) {
  # busca entradas de texto que en su mayoría sean únicas
  text_features <- c(names(data_set[sapply(data_set, is.character)]), names(data_set[sapply(data_set, is.factor)]))
  for (f_name in setdiff(text_features, features_to_ignore)) {
    f_vector <- as.character(data_set[,f_name])
    # tratar como texto sin procesar si los datos superan el mínimo_precent_unique
    if (length(unique(as.character(f_vector))) > (nrow(data_set) * minimum_unique_threshold)) {
      data_set[,paste0(f_name, '_word_count')] <- sapply(strsplit(f_vector, " "), length)
      data_set[,paste0(f_name, '_character_count')] <- nchar(as.character(f_vector))
      data_set[,paste0(f_name, '_first_word')] <- sapply(strsplit(as.character(f_vector), " "), `[`, 1)
      # remover las columnas originales
      data_set[,f_name] <- NULL
    }
  }
  return(data_set)
}




Impute_Features <- function(data_set, features_to_ignore=c(),
                            use_mean_instead_of_0=TRUE,
                            mark_NAs=FALSE,
                            remove_zero_variance=FALSE) {
  for (feature_name in setdiff(names(data_set), features_to_ignore)) {
    print(feature_name)
    # remover las columnas con cero varianza
    if (remove_zero_variance) {
      if (length(unique(data_set[, feature_name]))==1) {
        data_set[, feature_name] <- NULL
        next
      }
    }
    if (mark_NAs) {
      # tiene en cuenta cada campo que contiene datos faltantes o incorrectos
      if (any(is.na(data_set[,feature_name]))) {
        # crer columna binaria antes de imputar
        newName <- paste0(feature_name, '_NA')
        data_set[,newName] <- as.integer(ifelse(is.na(data_set[,feature_name]),1,0)) }
      if (any(is.infinite(data_set[,feature_name]))) {
        newName <- paste0(feature_name, '_inf')
        data_set[,newName] <- as.integer(ifelse(is.infinite(data_set[,feature_name]),1,0)) }
    }
    if (use_mean_instead_of_0) {
      data_set[is.infinite(data_set[,feature_name]),feature_name] <- NA
      data_set[is.na(data_set[,feature_name]),feature_name] <- mean(data_set[,feature_name], na.rm=TRUE)
    } else {
      data_set[is.na(data_set[,feature_name]),feature_name] <- 0
      data_set[is.infinite(data_set[,feature_name]),feature_name] <- 0
    }
  }
  return(data_set)
}

# Cambiar el formato de fecha
Fix_Date_Features <- function(data_set) {
  text_features <- c(names(data_set[sapply(data_set, is.character)]), names(data_set[sapply(data_set, is.factor)]))
  for (feature_name in text_features) {
    feature_vector <- as.character(data_set[,feature_name])
    # asumo el siguente patrón '01/11/2012'
    date_pattern <- '[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]'
    if (max(nchar(feature_vector)) == 10) {
      if (sum(grepl(date_pattern, feature_vector)) > 0) {
        print(paste('Casting feature to date:',feature_name))
        data_set[,feature_name] <- as.Date(feature_vector, format="%d/%m/%Y")
      }
    }
  }
  return (data_set)
}


Feature_Engineer_Dates <- function(data_set, remove_original_date=TRUE) {
  require(lubridate)
  data_set <- data.frame(data_set)
  date_features <- names(data_set[sapply(data_set, is.Date)])
  for (feature_name in date_features) {
    data_set[,paste0(feature_name,'_DateInt')] <- as.numeric(data_set[,feature_name])
    data_set[,paste0(feature_name,'_Month')] <- as.integer(format(data_set[,feature_name], "%m"))
    data_set[,paste0(feature_name,'_ShortYear')] <- as.integer(format(data_set[,feature_name], "%y"))
    data_set[,paste0(feature_name,'_LongYear')] <- as.integer(format(data_set[,feature_name], "%Y"))
    data_set[,paste0(feature_name,'_Day')] <- as.integer(format(data_set[,feature_name], "%d"))
    # week day number requires first pulling the weekday label, creating the 7 week day levels, and casting to integer
    data_set[,paste0(feature_name,'_WeekDayNumber')] <- as.factor(weekdays(data_set[,feature_name]))
    levels(data_set[,paste0(feature_name,'_WeekDayNumber')]) <- list(Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6, Sunday=7)
    data_set[,paste0(feature_name,'_WeekDayNumber')] <- as.integer(data_set[,paste0(feature_name,'_WeekDayNumber')])
    data_set[,paste0(feature_name,'_IsWeekend')] <- as.numeric(grepl("Saturday|Sunday", weekdays(data_set[,feature_name])))
    data_set[,paste0(feature_name,'_YearDayCount')] <- yday(data_set[,feature_name])
    data_set[,paste0(feature_name,'_Quarter')] <- lubridate::quarter(data_set[,feature_name], with_year = FALSE)
    data_set[,paste0(feature_name,'_Quarter')] <- lubridate::quarter(data_set[,feature_name], with_year = TRUE)
    if (remove_original_date)
      data_set[, feature_name] <- NULL
  }
  return(data_set)
}



Feature_Engineer_Integers <- function(data_set, features_to_ignore=c()) {
  require(infotheo)
  data_set <- data.frame(data_set)
  for (feature_name in setdiff(names(data_set), features_to_ignore)) {
    if (class(data_set[,feature_name])=='numeric' | class(data_set[,feature_name])=='integer') {
      feature_vector <- data_set[,feature_name]
      if (all((feature_vector - round(feature_vector)) == 0)) {
        # make sure we have more than 2 values excluding NAs
        if (length(unique(data_set[,feature_name][!is.na(data_set[,feature_name])])) > 2) {
          print(feature_name)
          data_set[,paste0(feature_name,'_IsZero')] <- ifelse(data_set[,feature_name]==0,1,0)
          data_set[,paste0(feature_name,'_IsPositive')] <- ifelse(data_set[,feature_name]>=0,1,0)
          # separate data into two bins
          data_discretized <- discretize(data_set[,feature_name], disc='equalfreq', nbins=2)
          data_set[,paste0(feature_name,'_2Bins')] <- data_discretized$X
          if (length(unique(data_set[,feature_name][!is.na(data_set[,feature_name])])) > 4) {
            # try 4 bins
            data_discretized <- discretize(data_set[,feature_name], disc='equalfreq', nbins=4)
            data_set[,paste0(feature_name,'_4Bins')] <- data_discretized$X
          }
        }
      }
    }
  }
  return (data_set)
}





Feature_Engineer_Numbers <- function(data_set, features_to_ignore=c()) {
  require(infotheo)
  data_set <- data.frame(data_set)
  date_features <- setdiff(names(data_set[sapply(data_set, is.numeric)]), features_to_ignore)
  for (feature_name in date_features) {
    feature_vector <- data_set[,feature_name]
    if (is.integer(feature_vector) | is.numeric(feature_vector)) {
      if (any((feature_vector - round(feature_vector)) != 0)) {
        # asegúrese de que tenemos más de 2 valores excluyendo NAs
        if (length(unique(data_set[,feature_name][!is.na(data_set[,feature_name])])) > 2) {
          print(feature_name)
          # transformación polinómica
          poly_vector <- poly(x=feature_vector, degree = 2)
          data_set[,paste0(feature_name, "_poly1")] <- poly_vector[,1]
          data_set[,paste0(feature_name, "_poly2")] <- poly_vector[,2]
          # transformación logaritmica
          data_set[,paste0(feature_name, "_log")] <- log(x = feature_vector)
          # transformación exponencial
          data_set[,paste0(feature_name, "_exp")] <- exp(x = feature_vector)
          # redondeo
          data_set[,paste0(feature_name, "_rnd")] <- round(x = feature_vector, digits = 0)
          # separar en 2 grupos
          data_discretized <- discretize(data_set[,feature_name], disc='equalfreq', nbins=2)
          data_set[,paste0(feature_name,'_2Bins')] <- data_discretized$X
        }
      }
    }
  }
  return(data_set)
}


