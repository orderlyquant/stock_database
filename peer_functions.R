## All peer functions should work off of the data returned by the 
## `db_get_` family of functions






prep_peer_correlation_data_by_symbol <- function(con, in.symbol, from = NULL, to = NULL) {
    
    peers <- db_get_peers_by_symbol(con, in.symbol)
    peer_group_name <- peers$peer_group[[1]]
    base_id <- peers %>% filter(symbol == in.symbol) %>% pull(uid)
    base_symbol <- in.symbol
    base_name <- peers %>% filter(symbol == in.symbol) %>% pull(name)
    
    peer_prices <- db_get_peers_adjusted_price_by_symbol(
        con = con,
        in.symbol = in.symbol,
        from = from,
        to = to
    )
    
    data_start <- min(peer_prices$effective_date)
    data_end <- max(peer_prices$effective_date)
    
    tbl <- 
        left_join(
            peer_prices %>%
                filter(uid == base_id) %>%
                select(uid, effective_date, adjusted_price, total_return),
            peer_prices %>%
                filter(uid != base_id) %>%
                select(uid, effective_date, adjusted_price, total_return),
            by = "effective_date",
            suffix = c("_1", "_2")
        ) %>%
        select(effective_date, matches("uid"), everything()) %>%
        arrange(uid_2, effective_date)
    
    full_cor <- tbl %>%
        group_by(uid_1, uid_2) %>%
        summarize(
            cor = cor(total_return_1, total_return_2, use = "pairwise.complete.obs"),
            .groups = "keep"
        ) %>%
        left_join(peers, by = c("uid_2" = "uid")) %>%
        ungroup() %>%
        select(uid_1, uid_2, symbol, name, cor)
    
    full_ret <- tbl %>%
        group_by(uid_1, uid_2) %>%
        summarize(
            tret_1 = (last(adjusted_price_1) / first(adjusted_price_1))-1,
            tret_2 = (last(adjusted_price_2) / first(adjusted_price_2))-1,
            tret_rel = tret_2 - tret_1
        ) %>%
        ungroup()
    
    return(
        list(
            base_id = base_id,
            base_symbol = base_symbol,
            base_name = base_name,
            data_start = data_start,
            data_end = data_end,
            peers = peers,
            peer_group_name = peer_group_name,
            tbl = tbl,
            full_cor = full_cor,
            full_ret = full_ret
        )
    )
}


create_peer_return_plot <- function(data, tb_n = 4) {
    
    peers_data <- bind_rows(
        data$tbl %>%
            distinct(effective_date, uid_1, adjusted_price_1, total_return_1) %>%
            rename(
                uid = uid_1,
                adjusted_price = adjusted_price_1,
                total_return = total_return_1
            ),
        
        data$tbl %>%
            select(
                uid = uid_2, effective_date,
                adjusted_price = adjusted_price_2,
                total_return = total_return_2
            )
    ) %>% 
        group_by(uid) %>% 
        arrange(effective_date) %>%
        mutate( tret_idx = adjusted_price / first(adjusted_price) ) %>% 
        ungroup() %>%
        left_join(
            data$peers %>% select(uid, symbol),
            by = "uid"
        )
    
    
    
    top_bottom_ids <- peers_data %>%
        filter(effective_date == max(effective_date)) %>%
        arrange(desc(tret_idx)) %>%
        filter(!between(row_number(), (tb_n + 1), n() - tb_n)) %>%
        pull(uid)
    
    
    peers_mean <- peers_data %>%
        group_by(effective_date) %>% 
        summarise(
            total_return = mean(total_return, na.rm = TRUE)
        ) %>% 
        mutate(
            tret_idx = ifelse(effective_date == first(effective_date), 1.0, 1 + (total_return / 100)),
            tret_idx = cumprod(tret_idx),
            symbol = "Grp Avg"
        )
    
    base_data <- peers_data %>% filter(uid == data$base_id)
    other_peers_data <- peers_data %>% filter(uid %in% top_bottom_ids)
    
    base_percentile <- peers_data %>%
        filter(effective_date == max(effective_date)) %>%
        summarise(symbol = symbol, percentile = percent_rank(tret_idx)) %>%
        filter(symbol == data$base_symbol) %>%
        pull(percentile)
    
    
    ylim <- round(max(abs(min(peers_data$tret_idx)-1),abs(max(peers_data$tret_idx)-1))*1.05,2)
    xlim <- ymd(start_date)
    
    
    other_peers_data %>% 
        ggplot(aes(ymd(effective_date), tret_idx, color = fct_reorder2(symbol, effective_date, tret_idx))) +
        geom_line(alpha = 0.5) +
        scale_x_date(limits = c(xlim, NA), date_breaks = "3 months", date_labels = "%b %y") +
        scale_y_continuous(limits = c(max(1-ylim,0), 1+ylim)) +
        geom_hline(yintercept = 1, color = "black", size = 1, alpha = 1/3) +
        geom_line(data = base_data, mapping = aes(ymd(effective_date), tret_idx), color = "dark red") +
        geom_line(data = peers_mean, mapping = aes(ymd(effective_date), tret_idx), color = "black") + 
        labs(
            title = glue("{cor_list$peer_group_name} Peer Group"),
            subtitle = glue("{cor_list$base_name} in {round(base_percentile*100, 0)}th-percentile in peer group"),
            color = "Other Peers",
            y = "Total Return Index",
            x = "",
            caption = str_c("Highlighted:",cor_list$base_name, "in dark red; peer group average in black.", sep = " ")
        ) +
        theme_ipsum() +
        scale_color_oq_div(reverse = TRUE)
}
