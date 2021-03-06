#********************************************************************************
#  Pride & Protest 
#  Francisco Olivos
#  June 11
#  Balance and main models
#********************************************************************************

#Still to do and consider:
#            - Tenemos que preparar varias cosas en el material suplementario. 
#              pero eso lo podemos hacer despues.
#            - Probare algunos analisis por submuestra. Principalmente hay un 
#              perfil de jovenes, hombres y mas educados que se asocia con protesta.
#              quiero ver si hay diferencias significativas entre esos grupos que podamos destacar. 
#            - Incluir el grafico de las encuestas por dia es un poco riesgoso. Porque luego de la segunda tanda
#              de encuesta, se volvio a parar una semana. Y si mostramos eso nos van a cuestionar inmediatamente. 

#:::::::::::::::::::::::::Balance

#La idea es comparar las medias y distribuciones de las variables. Pueden ser
#boxplots o la media con el intervalo de confianza. Cualquiera visualizacion
#que permita mostrar el balance va a estar bien. Hay unas ligeras diferencias
#por zonas geograficas, pero con la correcion del ebal quedan bien. 

#Abajo genere unos graficos con la media de cada una de las variables. Ojo con
#que uso la base de datos prideLW. Es un subset que considera solo casos sin 
#missing. La variable "sample" viene de la base de datos en Stata. 

#Las variables son casi todas 0 a 1. Son las variables categoricas transformadas
#en binarias. Reportar la media de eso esta perfect. 

library(tidyverse)

pride <- readRDS("data/02-base_analisis.rds")

pride %>% 
  transmute(across(c(gender, age_4, geozone, edu, household, 
                     pride_CL, pride_esf, energy, pride_sym, pride_dev, pride_pl, treat),
                   as.numeric)) %>% 
  summarise(across(everything(), max))

table(pride$pride_CL, useNA = 'ifany')


# Change inplicit to explicit NA
pride <- pride %>% 
  mutate(across(c(gender, age_4, geozone, edu, household, 
                  pride_CL, pride_esf, energy, pride_sym, pride_dev, pride_pl),
                ~replace(., . %in% c(88, 99), NA)))


# Change variables to factor
pride <- pride %>% 
  mutate(across(c(gender, age_4, geozone, edu, household, 
                  pride_CL, pride_esf, energy, pride_sym, pride_dev, pride_pl),
                as_factor))

table(pride$pride_CL, useNA = 'ifany')

# Keep cases with full response
pride <- pride %>% 
  mutate(sample = rowSums(across(c(gender, age_4, geozone, edu, household, 
                                   pride_CL, pride_esf, energy, pride_sym, pride_dev, pride_pl, treat), 
                                 is.na)))
count(pride, sample)

prideLW <- pride %>% 
  filter(sample == 0)

saveRDS(prideLW, 'data/03-prideLW.rds')



# Chart with diferences ---------------------------------------------------
# 
# Create new dataframe mpg_means_se
df_category <- prideLW %>% 
  select(id, treat, gender, age_4, geozone, edu, household) %>% 
  pivot_longer(cols = c(gender, age_4, geozone, edu, household), 
               names_to = 'variable', 
               values_to = 'category')

df_category_diff_treat <- df_category %>% 
  group_by(variable, category) %>% 
  summarise(mean_se(treat))


df_category_diff_treat %>% 
  ggplot(aes(x = category, y = y)) +
  geom_linerange(aes(ymin = 0, ymax = y, 
                     colour = stage(variable,
                                    after_scale = prismatic::clr_alpha(colour, alpha = .3))), 
                 size = 2) + 
  geom_errorbar(aes(ymin = ymin, ymax = ymax,
                    colour = stage(variable,
                                   after_scale = prismatic::clr_darken(colour, shift = .5))), 
                size = 1) +
  geom_point(size = 2) +
  facet_grid(cols = vars(variable),
             scales = 'free_x', space = 'free_x') +
  scale_y_continuous('Proportion of treated', 
                     limits = c(0,1),
                     labels = scales::percent) +
  scale_colour_brewer(palette = 'Set1', guide = 'none') + 
  coord_cartesian(expand = FALSE) + 
  labs(title = "Sample balance", 
       subtitle = 'Difference between treated and non-treated in five categories',
       x = " ") +
  theme_minimal() + 
  theme(axis.text.x = element_text(angle = 90, size = rel(1), 
                                   hjust = 1, vjust = 0.5))
  
ggsave('plots/03-df_category_diff_treat.png',
       scale = 1.25,
       width = 14, height = 8,
       units = 'cm')


# Entropy Balancing sample ------------------------------------------------
# 
# Package `ebal` Entropy reweighting to create balanced samples
library(ebal)

prideLW <- prideLW %>% 
  arrange(treat, id)

# entropy balancing
eb.out <- ebal::ebalance(Treatment = prideLW$treat, 
                         X = transmute(prideLW, 
                                       across(c(gender, age, geozone, edu, household), as.integer)))

summary(eb.out)

# Adding weight vector to database.
prideLW <- prideLW %>% 
  mutate(w_ebal_r = c(eb.out$w, rep(1, nrow(.) - length(eb.out$w))))

prideLW %>% 
  group_by(treat) %>% 
  slice_head(n = 5) %>% 
  select(id, treat, webal, w_ebal_r)

prideLW %>% 
  mutate(diff_ebal = webal - w_ebal_r, .keep = 'used') %>% 
  arrange(diff_ebal)

# Check means
prideLW_ebal <- prideLW %>% 
  mutate(treat, w_ebal_r, webal, 
         across(c(gender, age, geozone, edu, household), as.integer), 
         .keep = 'used')


# means in raw data: control and treatement group
prideLW_ebal %>% 
  group_by(treat) %>% 
  summarise(cases = n(), 
            across(c(gender, age, geozone, edu, household), 
                   mean))

# means in reweighted control group data (R)
prideLW_ebal %>% 
  filter(!treat) %>% 
  summarise(cases = n(), 
            across(c(gender, age, geozone, edu, household), 
                   weighted.mean, w = w_ebal_r))

# means in reweighted control group data (Stata)
prideLW_ebal %>% 
  filter(!treat) %>% 
  summarise(cases = n(), 
            across(c(gender, age, geozone, edu, household), 
                   weighted.mean, w = webal))
