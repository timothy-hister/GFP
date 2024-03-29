library(shiny)
library(shinyWidgets)
library(plotly)
library(tidyverse)
library(htmltools)
library(readxl)
library(reactable)
library(manipulateWidget)
options(scipen = 999)
options(warn=-1)

# FUNCTIONS

`%,%` = function(a,b) paste0(a,b)
`%,,%` = function(a,b) paste(a,b)

info_icon = function(text, message="") tags$span(text, tags$i(class = "glyphicon glyphicon-info-sign", style = "color:#0072B2;", title = message))

# IMPORT COUNTRY INFO

countries = read_excel("www/countries.xlsx")
blurbs = countries %>% select(country, blurb) %>% deframe()
countries = countries %>% select(-blurb) 
countries = bind_cols(country = names(countries), t(countries)) %>% as_tibble()
names(countries) = unlist(countries[1,])
countries = countries[2:nrow(countries), ] %>% arrange(country)
countries_all = countries$country %>% unique()
currencies = select(countries, country, currency_symbol, suffix, reverse_marks)
flags = countries %>% select(country, flag_symbol)
countries = countries %>% 
  select(-(c(flag_symbol, currency_symbol, suffix, reverse_marks))) %>%
  pivot_longer(cols=-1, names_to = "variable") %>%
  arrange(country, variable) %>%
  mutate(value = as.double(value))
event_vars = countries$variable %>% unique()
currency_vars = event_vars[grep("^(cost)|(revenue)|(price)|(fixed)", event_vars)]

# DEFINE UI

ui = fluidPage(
  
  # GFP uses Raleway font
  tags$head(
    tags$style(HTML("
      body {
        font-family: Raleway;
    "))
  ),
  
  # App title
  titlePanel(title=div(style="margin-bottom: 30px;", a(href="https://globalfoodpartners.com/", img(src = "GFP_logo.png", width = 200), class = "pull-left", style="margin-right: 30px;"), h1("Cage-Free Egg Business Calculator")), windowTitle = "Cage-Free Egg Business Calculator"),
  
  # Sidebar layout with input and output definitions
  sidebarLayout(
    
    # Sidebar to demonstrate various slider options
    sidebarPanel(
      
      pickerInput(
        inputId="country", 
        label="Your Country", 
        multiple = F, 
        choices = flags$country, 
        options = list(title = "Pick a country!"),
        choicesOpt = list(content = purrr::map2(flags$flag_symbol, flags$country, function(flag, text) shiny::HTML(paste(tags$img(src=flag %,% ".svg", width=30, height=22), text))))),
      sliderInput("num_years", label="Number of Years to Forecast",  value = 10, min=1, max=50, step=1),
      
      h3("Basic Statistics"),
      numericInputIcon("flock_size", info_icon("Flock size (number of birds)", blurbs["flock_size"]), value = NULL, min=0, step=1000),
      numericInputIcon("mortality", info_icon("Mortality rate (%)", blurbs['mortality']), value = NULL, min=0, max=100, step=.5, icon=list(NULL, icon("percent"))),
      sliderInput("period_length", info_icon("Laying period (months)", blurbs['period_length']), value = 12, min=1, max=24, step=1),
      numericInputIcon("lay_percent", info_icon("Average rate of lay (%)", blurbs['lay_percent']), value = NULL, min=0, max=100, step=.5, icon=list(NULL, icon("percent"))),
      sliderInput("transition_length", info_icon("Down Time Between Flocks (Months)", blurbs['transition_length']), value = 2, min=1, max=12, step=1),
      numericInputIcon("breakage", info_icon("Eggs lost (%)", blurbs['breakage']), value = NULL, min=0, max=100, step=.5, icon=list(NULL, icon("percent"))),
      
      h3("Revenues"),
      numericInputIcon("price_egg", info_icon("Selling Price per Egg", blurbs['price_egg']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("price_spent", info_icon("Selling price per hen", blurbs['price_spent']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("revenue_manure", info_icon("Sale of manure (per flock)", blurbs['revenue_manure']), value = NULL, min=0L, step=1, icon = icon("dollar", verify_fa=F)),
      
      h3("Variable Costs"),
      numericInputIcon("cost_feed", info_icon("Feed costs (per month)", blurbs['cost_feed']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_labor", info_icon("Labour costs (per month)", blurbs['cost_labor']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_equip", info_icon("Equipment & Maintanance (per year)", blurbs['cost_equip']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_pullet", info_icon("Replacement pullets (per pullet)", blurbs['cost_pullet']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_litter", info_icon("Litter costs (per flock)", blurbs['cost_litter']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_vet", info_icon("Veterinary care and medications (per flock)", blurbs['cost_vet']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_utilities", info_icon("Utilities costs (per year)
", blurbs['cost_utilities']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("cost_other", info_icon("Other costs (per year)", blurbs['cost_other']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      
      h3("Fixed Costs"),
      numericInputIcon("fixed_land", info_icon("Land (yearly)", blurbs['fixed_land']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F)),
      numericInputIcon("fixed_other", info_icon("Other fixed costs (yearly)", blurbs['fixed_other']), value = NULL, min=0, step=.5, icon = icon("dollar", verify_fa=F))
    ),
    
    # Main panel for displaying outputs
    mainPanel(
      
      conditionalPanel(
        condition = "input.country != ''",
        tabsetPanel(
          tabPanel("Revenues",
            combineWidgetsOutput("g_revenue", height=600),
            downloadButton("d_revenue", "Download Data"),
            reactableOutput("t_revenue")
          ),
          tabPanel("Costs",
            plotlyOutput("g_cost"),
            downloadButton("d_cost", "Download Data"),
            reactableOutput("t_cost")
          ),
          tabPanel("Profits",
            plotlyOutput("g_profit"),
            downloadButton("d_profit", "Download Data"),
            reactableOutput("t_profit"))
        )
      )
    )
  )
)

# DEFINE SERVER LOGIC

server = function(input, output, session) {
  
  currency_format = eventReactive(
    input$country,
    if (input$country == "") list(prefix="$", suffix="", big.mark=",", decimal.mark=".") else
      filter(currencies, country==input$country) %>% 
        select(-country) %>% 
        mutate(prefix = case_when(is.na(suffix) ~ currency_symbol, T ~ "")) %>%
        mutate(suffix = case_when(!is.na(suffix) ~ currency_symbol, T ~ "")) %>%
        mutate(big.mark = case_when(is.na(reverse_marks) ~ ",", T ~ ".")) %>%
        mutate(decimal.mark = case_when(is.na(reverse_marks) ~ ".", T ~ ",")) %>%
        mutate(accuracy = 1) %>%
        select(accuracy, prefix, suffix, big.mark, decimal.mark) %>%
        as.list()
  )
  
  currency_symbol = eventReactive(
    input$country,
    if (input$country == "") "$" else
      filter(currencies, country==input$country) %>% 
        pull(currency_symbol)
  )
  
  observeEvent(input$country, {
    for (var in event_vars) updateNumericInput(session, inputId = var, value = filter(countries, country == input$country, variable==var) %>% pull(value))
    for (var in currency_vars) updateNumericInputIcon(session, inputId = var, icon = list(currency_symbol()))
  })
  
  observe({
    
    # Make important tables
    survival = reactive({(1 - input$mortality / 100) ^ (1/(input$period_length - 1))})
    monthly = reactive({
      tibble(month = 1:(12 * (input$num_years))) %>%
        mutate(
          year = ceiling(month / 12),
          period = ceiling(month / input$period_length),
          period_rank = (month - 1) %% (input$period_length + input$transition_length) + 1,
          is_transition = period_rank > input$period_length,
          num_hens = case_when(
            period_rank == 1 ~ as.double(input$flock_size),
            is_transition ~ 0.0,
            T ~ input$flock_size * (survival() ^ (period_rank - 1))),
          num_eggs = num_hens * 30.5 * (1 - input$breakage / 100) * input$lay_percent / 100,
          revenue_eggs = num_eggs * input$price_egg,
          revenue_spent = case_when(period_rank == input$period_length + 1 ~ lag(num_hens) * input$price_spent, T ~ 0),
          revenue_manure = case_when(period_rank == input$period_length + 1 ~ as.double(input$revenue_manure), T ~ 0.0),
          cost_feed = case_when(!is_transition ~ as.double(input$cost_feed), T ~ 0.0),
          cost_labor = as.double(input$cost_labor),
          cost_equip = input$cost_equip / 12,
          cost_pullet = case_when(
            year == 1 & period == 1 & period_rank == 1 ~ as.double(input$cost_pullet * input$flock_size), 
            is_transition & !lead(is_transition) ~ as.double(input$cost_pullet * input$flock_size),
            T ~ 0.0),
          cost_litter = case_when(period_rank == 1 ~ as.double(input$cost_litter), T ~ 0.0),
          cost_vet = case_when(!is_transition ~ input$cost_vet / input$period_length, T ~ 0.0),
          cost_utilities = input$cost_utilities / 12,
          cost_other = input$cost_other / 12
        ) %>%
        ungroup()
    })
    
    yearly = reactive({
      monthly() %>%
        group_by(year) %>%
        summarise_if(is.numeric, sum) %>%
        ungroup() %>%
        select(year, num_eggs, starts_with(c("revenue", "cost"))) %>%
        mutate(
          fixed_land = input$fixed_land,
          fixed_other = input$fixed_other,
          revenue_total = revenue_eggs + revenue_spent + revenue_manure,
          cost_variable_total = cost_feed + cost_labor + cost_equip + cost_pullet + cost_litter + cost_vet + cost_utilities + cost_other, 
          fixed_cost_total = fixed_land + fixed_other,
          cost_total = cost_variable_total + fixed_cost_total,
          profit = revenue_total - cost_total
        )
    })
    
    # Revenue tables & graphs
    revenue = reactive(
      yearly() %>% 
        select(year, num_eggs, revenue_eggs, revenue_spent, revenue_manure, revenue_total) %>% 
        mutate_at(c("num_eggs", "revenue_eggs", "revenue_spent", "revenue_manure", "revenue_total"), ~round(., 0)) %>%
        setNames(c("Year", "Number of Eggs", "Revenue from Eggs", "Revenue from Spent Hens", "Revenue from Manure", "Total Revenue"))
    )
    
    output$t_revenue = renderReactable(
      reactable(
        revenue(), 
        highlight=T, 
        columns = list(
          Year = colDef(cell = function(x) x),
          `Number of Eggs` = colDef(cell = function(y) do.call(scales::number, c(list(x=y), currency_format()[c("big.mark", "decimal.mark")])))
        ),
        defaultColDef = colDef(cell = function(y) do.call(scales::number, c(list(x=y), currency_format())))
      )
    )
    
    revenue_p1 = ggplotly(
      revenue() %>%
        select(`Year`, `Number of Eggs`) %>%
        pivot_longer(cols = 2) %>%
        mutate(facet = name) %>%
        ggplot() +
        theme_light() +
        aes(x=`Year`, y=value, color=name) +
        geom_line() + geom_point() +
        scale_x_continuous(breaks=revenue()$`Year`) +
        scale_y_continuous(labels = function(y) do.call(scales::number, c(list(x=y), currency_format()[c("accuracy", "big.mark", "decimal.mark")]))) +
        facet_wrap(~facet) +
        theme(legend.position = 'none') +
        theme(text=element_text(family="Raleway")) +
        labs(color=NULL, x=NULL, y=NULL)
    )
    
    revenue_p2 = ggplotly(
      revenue() %>%
        select(`Year`, "Revenue from Eggs", "Revenue from Spent Hens", "Revenue from Manure") %>%
        pivot_longer(cols = 2:4) %>%
        mutate(facet = name) %>%
        ggplot() +
        theme_light() +
        aes(x=`Year`, y=value, color=name) +
        geom_line() + geom_point() +
        scale_x_continuous(breaks=revenue()$`Year`) +
        scale_y_continuous(labels = function(y) do.call(scales::number, c(list(x=y), currency_format()))) +
        facet_wrap(~facet, scales='free_y', ncol=1) +
        theme(legend.position = 'none') +
        theme(text=element_text(family="Raleway")) +
        scale_color_manual(values = c("#7CAE00", "#00BFC4", "#C77CFF")) +
        labs(color=NULL, y=NULL)
    )
    
    output$g_revenue = renderCombineWidgets(manipulateWidget::combineWidgets(revenue_p1, revenue_p2, nrow = 2, rowsize = c(1,2), byrow = T))
    output$d_revenue = downloadHandler(filename = "revenue_data.csv", content = function(file) write.csv(revenue(), file, row.names = FALSE))
    
    # Cost tables & graphs
    cost = reactive(
      yearly() %>% 
        select(year, cost_feed, cost_labor, cost_equip, cost_pullet, cost_litter, cost_vet, cost_utilities, cost_other, fixed_land, fixed_other) %>%
        mutate_at(c("cost_feed", "cost_labor", "cost_equip", "cost_pullet", "cost_litter", "cost_vet", "cost_utilities", "cost_other", "fixed_land", "fixed_other"), ~round(., 0)) %>%
        setNames(c("Year", "Feed", "Labor", "Equipment", "Pullet", "Litter", "Veterinarian/Vaccine", "Utilities", "Other", "Land", "Other Fixed"))
    )
    
    output$t_cost = renderReactable(
      reactable(
        cost(), 
        highlight=T, 
        columns = list(
          Year = colDef(cell = function(x) x)
        ), 
        defaultColDef = colDef(cell = function(y) do.call(scales::number, c(list(x=y), currency_format())))
      )
    )
    
    output$g_cost = renderPlotly(
      cost() %>%
       pivot_longer(cols = 2:11) %>%
       mutate(name = factor(name, levels = c("Year", "Feed", "Labor", "Equipment", "Pullet", "Litter", "Veterinarian/Vaccine", "Utilities", "Other", "Land", "Other Fixed"))) %>%
       mutate(facet = "Cost") %>%
       ggplot() +
       theme_light() +
       aes(x=`Year`, y=value, color=name) +
       geom_line() + geom_point() +
       scale_x_continuous(breaks=cost()$`Year`) +
       scale_y_continuous(labels = function(y) do.call(scales::number, c(list(x=y), currency_format()))) +
       theme(legend.position = 'bottom') +
       theme(text=element_text(family="Raleway")) +
       labs(color=NULL, y=NULL) +
       facet_wrap(~facet)
    )
    
    output$d_cost = downloadHandler(filename = "cost_data.csv", content = function(file) write.csv(cost(), file, row.names = FALSE))
    
    # Profit tables & graphs
    profit = reactive(
      yearly() %>% 
        select(year, cost_total, revenue_total, profit) %>% 
        mutate_at(c("cost_total", "revenue_total", "profit"), ~round(., 0)) %>%
        setNames(c("Year", "Total Cost", "Total Revenue", "Total Profit"))
    )
    
    output$t_profit = renderReactable(
      reactable(
        profit(), 
        highlight=T, 
        columns = list(
          Year = colDef(cell = function(x) x)
        ), 
        defaultColDef = colDef(cell = function(y) do.call(scales::number, c(list(x=y), currency_format())))
      )
    )
    
    output$g_profit = renderPlotly(
      profit() %>%
        pivot_longer(cols = 2:4) %>%
        mutate(facet = "Profit") %>%
        ggplot() +
        theme_light() +
        aes(x=`Year`, y=value, color=name) +
        geom_line() + geom_point() +
        scale_x_continuous(breaks=profit()$`Year`) +
        scale_y_continuous(labels = function(y) do.call(scales::number, c(list(x=y), currency_format()))) +
        theme(legend.position = 'left') +
        theme(text=element_text(family="Raleway")) +
        labs(color=NULL, y=NULL) +
        facet_wrap(~facet)
    )
    
    output$d_profit = downloadHandler(filename = "profit_data.csv", content = function(file) write.csv(profit(), file, row.names = FALSE))
  
  })
}

# RUN THE APPLICATION
shinyApp(ui = ui, server = server)