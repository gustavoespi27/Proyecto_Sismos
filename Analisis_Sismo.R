# ==============================================================================
# Proyecto: Analítica de Datos Sísmicos Globales (1900-2025) - Análisis en R
# Requiere: sismos_procesados.csv (generado por analisis_python.ipynb)
# Genera:   Mapa_Final_SinRepeticion.html, Grafico_Comparativo_Global.png
# ==============================================================================
library(tidyverse)
library(stringr)
library(leaflet)
library(htmlwidgets)
library(gridExtra)

# CARGA DE DATOS (Aseguramos ruta)
tryCatch({
  datos <- read_csv("sismos_procesados.csv")
}, error = function(e) { stop("❌ Error: Carga el archivo csv primero.") })



# ==============================================================================
# PARTE 1: MAPA ARREGLADO (SIN REPETICIÓN)
# ==============================================================================

# 1. Filtrar para el mapa (Solo sismos grandes para que no se trabe)
datos_mapa <- datos %>%
  filter(magnitud >= 5.5)

# 2. Definir colores
colores <- colorNumeric(palette = c("orange", "red", "darkred"), domain = datos_mapa$magnitud)

print("Generando mapa arreglado...")

# 3. Crear Mapa con el arreglo "noWrap"
mapa_arreglado <- leaflet(datos_mapa) %>%
  # --- AQUÍ ESTÁ EL TRUCO PARA QUE NO SE REPITA ---
  addTiles(options = tileOptions(noWrap = TRUE)) %>%
  # ------------------------------------------------
  addCircleMarkers(
    ~longitud, ~latitud,
    radius = ~magnitud * 1.1,
    color = ~colores(magnitud),
    stroke = FALSE, fillOpacity = 0.7,
    popup = ~paste("<b>Mag:</b>", magnitud, "<br>", lugar)
  ) %>%
  addLegend("bottomright", pal = colores, values = ~magnitud, title = "Magnitud") %>%
  # Esto asegura que la vista se centre en el mundo real y no en las copias
  setMaxBounds(lng1 = -180, lat1 = -90, lng2 = 180, lat2 = 90)

# Mostrar y Guardar
print(mapa_arreglado)
saveWidget(mapa_arreglado, file = "Mapa_Final_SinRepeticion.html")



# ==============================================================================
# PARTE 2 MEJORADA: COMPARACIÓN MULTI-REGIONAL
# ==============================================================================

# 1. Crear una clasificación regional más detallada
# Usamos 'case_when' para definir múltiples condiciones basadas en la Longitud.
datos_multi_region <- datos %>%
  mutate(
    Macro_Region = case_when(
      longitud >= -170 & longitud < -30 ~ "1. Americas",
      longitud >= -30 & longitud < 60   ~ "2. Europa/África",
      TRUE                              ~ "3. Asia/Pacífico"
    )
  )

print("Generando gráfico comparativo mejorado...")

# 2. Crear el Boxplot Mejorado
# TRUCO VISUAL: En el eje X, usamos 'reorder'.
# Esto ordena las regiones según la MEDIANA de su magnitud.
# La región con los sismos promedio más fuertes aparecerá a la derecha.
grafico_caja_pro <- ggplot(datos_multi_region,
                           aes(x = reorder(Macro_Region, magnitud, FUN = median),
                               y = magnitud,
                               fill = Macro_Region)) +
  # Hacemos los puntos atípicos (outliers) más transparentes para limpiar la vista
  geom_boxplot(outlier.alpha = 0.2, outlier.size = 1) +

  # Etiquetas y títulos profesionales
  labs(title = "Comparación Global de Intensidad Sísmica",
       subtitle = "Clasificación por Macro-Regiones (Ordenado por mediana)",
       y = "Magnitud (Escala Richter)", 
       x = "", # Quitamos la etiqueta X porque los nombres de las cajas ya lo dicen
       fill = "Región") +

  # Un tema visual limpio
  theme_minimal() +
  # Quitamos la leyenda lateral porque ya es redundante con las etiquetas de abajo
  theme(legend.position = "none",
        plot.title = element_text(face = "bold", size = 14))

# 3. Mostrar y Guardar
print(grafico_caja_pro)
ggsave("Grafico_Comparativo_Global.png", grafico_caja_pro, width = 8, height = 6)

# 4. (Opcional) El ANOVA para estas nuevas 3 regiones
# ¿Hay diferencia estadísticamente significativa entre ESTAS tres?
modelo_anova_pro <- aov(magnitud ~ Macro_Region, data = datos_multi_region)
print("--- RESULTADOS ANOVA MULTI-REGIÓN ---")
print(summary(modelo_anova_pro))



# ==============================================================================
# PARTE 3: RANKING DE PAÍSES
# ==============================================================================

# 1. LIMPIEZA AVANZADA Y TRADUCCIÓN
datos_limpios_pais <- datos %>%
  mutate(
    # Paso A: Intentamos sacar lo que está después de la coma
    Texto_Base = str_trim(str_extract(lugar, "[^,]+$")),
    Texto_Base = ifelse(is.na(Texto_Base), lugar, Texto_Base)
  ) %>%
  mutate(
    # Paso B: TRADUCCIÓN Y AGRUPACIÓN MANUAL
    # Agrupamos estados de USA y traducimos los países top
    Pais = case_when(
      # Agrupar Estados Unidos
      str_detect(lugar, "California|Alaska|Hawaii|Nevada|Washington|Oregon|Utah|Montana|Idaho|Wyoming|Texas|Oklahoma|Puerto Rico") ~ "Estados Unidos",

      # Traducciones comunes
      str_detect(Texto_Base, "Japan") ~ "Japón",
      str_detect(Texto_Base, "Chile") ~ "Chile",
      str_detect(Texto_Base, "Indonesia") ~ "Indonesia",
      str_detect(Texto_Base, "Philippines") ~ "Filipinas",
      str_detect(Texto_Base, "Russia|USSR") ~ "Rusia",
      str_detect(Texto_Base, "Mexico") ~ "México",
      str_detect(Texto_Base, "Peru") ~ "Perú",
      str_detect(Texto_Base, "New Zealand") ~ "Nueva Zelanda",
      str_detect(Texto_Base, "Papua New Guinea") ~ "Papúa Nueva Guinea",
      str_detect(Texto_Base, "Greece") ~ "Grecia",
      str_detect(Texto_Base, "Italy") ~ "Italia",
      str_detect(Texto_Base, "Turkey") ~ "Turquía",
      str_detect(Texto_Base, "China") ~ "China",
      str_detect(Texto_Base, "Taiwan") ~ "Taiwán",
      str_detect(Texto_Base, "Solomon Islands") ~ "Islas Salomón",
      str_detect(Texto_Base, "Argentina") ~ "Argentina",
      str_detect(Texto_Base, "Iran") ~ "Irán",
      str_detect(Texto_Base, "Afghanistan") ~ "Afganistán",
      str_detect(Texto_Base, "Colombia") ~ "Colombia",

      # Si no está en la lista, dejamos el original
      TRUE ~ Texto_Base
    )
  ) %>%
  # Paso C: FILTRO DE LIMPIEZA (Eliminamos "ruido" que no son países)
  # Sacamos filas que digan "Earthquake", "km of", "Sea", "Ocean", "Region"
  filter(!str_detect(Pais, "Earthquake|km |Region|Sea|Ocean|South of|North of|East of|West of|Rise|Ridge")) %>%
  # Agrupamos por el país ya limpio
  group_by(Pais) %>%
  summarise(
    Cantidad = n(),
    Promedio_Mag = mean(magnitud, na.rm = TRUE)
  )

# 2. PREPARAR LOS 4 TOPS (Ahora en Español)

# A. Más Sismos
top_cant <- datos_limpios_pais %>% arrange(desc(Cantidad)) %>% head(10)

# B. Menos Sismos (Filtramos > 5 para evitar nombres raros únicos)
bot_cant <- datos_limpios_pais %>% filter(Cantidad > 5) %>% arrange(Cantidad) %>% head(10)

# C. Mayor Magnitud Promedio (Filtramos > 10 eventos para que sea representativo)
top_mag <- datos_limpios_pais %>% filter(Cantidad >= 10) %>% arrange(desc(Promedio_Mag)) %>% head(10)

# D. Menor Magnitud Promedio
bot_mag <- datos_limpios_pais %>% filter(Cantidad >= 10) %>% arrange(Promedio_Mag) %>% head(10)

# 3. FUNCIÓN DE GRAFICADO (Optimizada para Español)
graficar_top <- function(data, x_col, titulo, color) {
  ggplot(data, aes(x = .data[[x_col]], y = reorder(Pais, .data[[x_col]]))) +
    geom_col(fill = color, width = 0.7) +
    geom_text(aes(label = round(.data[[x_col]], 1)), hjust = -0.1, size = 3.5, fontface = "bold") +
    labs(title = titulo, x = "", y = "") +
    theme_classic() +
    theme(
      plot.title = element_text(size = 11, face = "bold", hjust = 0),
      axis.text.y = element_text(size = 10, color = "black")
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.2))) # Espacio extra a la derecha
}

# 4. GENERAR LOS GRÁFICOS
p1 <- graficar_top(top_cant, "Cantidad", "A. Países con MÁS Sismos", "#8B0000") # Rojo Oscuro
p2 <- graficar_top(bot_cant, "Cantidad", "B. Países con MENOS Sismos (>5)", "#4682B4") # Azul Acero
p3 <- graficar_top(top_mag, "Promedio_Mag", "C. Mayor Magnitud Promedio", "#FF8C00") # Naranja
p4 <- graficar_top(bot_mag, "Promedio_Mag", "D. Menor Magnitud Promedio", "#228B22") # Verde

# 5. MOSTRAR (Usando gridExtra)
grid.arrange(p1, p2, p3, p4, ncol = 2)
