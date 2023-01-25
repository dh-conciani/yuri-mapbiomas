## carregar bibliotecas
library(ggplot2)
library(sf)
library(dplyr)

## juntar todas tabelas
files <- list.files('./table/gee', full.names=TRUE)

## 
dados <- as.data.frame(NULL)

## para cada arquivo
for (s in 1:length(files)) {
  print(files[s])
  
  ## read data
  data <- read.csv(files[s])
  
  data <- data[, !names(data) %in% c('system.index', '.geo')]    ## drop undesired columns from LCLUC
  print(unique(data$territory))
  ## read LCLUC dicitonary
  dict <- read.csv('./dict/mapbiomas-dict-en2.csv', sep= ';')
  
  ## translate LCLUC classes
  data2 <- as.data.frame(NULL)
  ## for each class id
  for (i in 1:length(unique(data$class_id))) {
    ## for each unique value
    y <- subset(dict, id == unique(data$class_id)[i])
    ## select matched class
    z <- subset(data, class_id == unique(data$class_id)[i])
    ## apply LCLUC translation
    z$level_0 <- gsub(paste0('^',y$id,'$'), y$level_0, z$class_id)
    z$level_1 <- gsub(paste0('^',y$id,'$'), y$level_1, z$class_id)
    z$level_1.2 <- gsub(paste0('^',y$id,'$'), y$level_1.2, z$class_id)
    z$level_2 <- gsub(paste0('^',y$id,'$'), y$level_2, z$class_id)
    z$level_3 <- gsub(paste0('^',y$id,'$'), y$level_3, z$class_id)
    z$level_4 <- gsub(paste0('^',y$id,'$'), y$level_4, z$class_id)
    
    ## bind into recipe
    data2 <- rbind(data2, z)
    rm(y, z)
  }
  
  rm(data, dict, i)
  
  ## parear com tabela areas de estudo 
  tabela <- as.data.frame(
    read_sf('./vector/sites.shp')
  )
  tabela <- tabela[, !names(tabela) %in% c('geometry')]    ## drop undesired columns 
  
  ## rename
  colnames(data2)[4] <- 'ID'
  
  ## join tables
  data <- left_join(data2, tabela, by= 'ID')
  
  ## calc percents
  recipe <- as.data.frame(NULL)
  for (i in 1:length(unique(data$ID))) {
    ## pega regiao
    x <- subset(data, ID == unique(data$ID)[i])
    
    ## extrair apenas ano do estudo
    x_i <- subset(x, year == unique(x$Ano))
    x_i$status <- 'T'
    ## extrair 10 anos antes
    ## se for menor, usar 1985
    if (unique(x$Ano) - 10 < 1985) {
      x_a <- subset(x, year == 1985)
      x_a$status <- 'T-10'
    } else {
      ## se tiver 10 anos, usa o ano - 10
      x_a <- subset(x, year == unique(x$Ano) - 10)
      x_a$status <- 'T-10'
    }
    
    ## bind
    x <- rbind(x_i, x_a)
    
    ## selecionar nivel
    y <- aggregate(x=list(area= x$area), by= list(year= x$year, ID= x$ID, buffer_size= x$buffer_size, status= x$status,
                                                  level = x$level_0), FUN= 'sum') ## AQUI ESCOLHE O NÍVEL
    
    temp <- as.data.frame(NULL)
    for (j in 1:length(unique(y$year))) {
      z <- subset(y, year == unique(y$year)[j])
      z$perc <- z$area / sum(z$area) * 100
      
      temp <- rbind(temp, z)
      
    }
    
    ## compute difference
    temp2 <- as.data.frame(NULL)
    for (k in 1:length(unique(temp$level))) {
      w <- subset(temp, level == unique(temp$level)[k])
      
      if (nrow(w) == 2) {
        w$perc_diff <- subset(w, status == "T")$perc - subset(w, status == "T-10")$perc 
        
      } else {
        
        if (unique(w$status) != 'T') {
          w$perc_diff <- 0 - subset(w, status == "T-10")$perc 
        }
        if (unique(w$status) != 'T-10') {
          w$perc_diff <- subset(w, status == "T")$perc - 0
        }
        
      }
      
      
      
      recipe <- rbind(recipe, w)
    }
    
  }
  rm(x, y, z, x_i, x_a, tabela, w)
  dados <- rbind(recipe, dados)
  
}

write.csv2(x= dados, file= './dados.csv', dec= ',')



