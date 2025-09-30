sheet_id <- Sys.getenv("UNCS_SHEET_ID")
password <- Sys.getenv("UNCS_PASSWORD")
stopifnot(nzchar(sheet_id), nzchar(password))

setwd('/Users/mtmorgan/a/git/uncs/r/')

library(dplyr)
requireNamespace("googlesheets4")
requireNamespace("memoise")
requireNamespace("rjsoncons")

## memoise data access functions
cache_location <- tools::R_user_dir("family-tree", "data")
cache <- cachem::cache_disk(cache_location)
read_sheet <-
    memoise::memoise(googlesheets4::read_sheet, cache = cache)
sheet_properties <-
    memoise::memoise(googlesheets4::sheet_properties, cache = cache)
range_read_cell <-
    memoise::memoise(googlesheets4::range_read_cells, cache = cache)

uid <- local({
    id <- 0
    function(n) {
        ids <- seq_len(n) + id
        id <<- id + n
        sprintf("%04d", ids)
    }
})

properties <- sheet_properties(sheet_id)
sheet_names <-
    properties |>
    pull(name)

find_edges <-
    function(name, key)
{
    if (length(name) <= 16L) {
        ## no genealogy information
        tbl <- tibble(
            person = character(),
            edge_label = character(),
            relation = character()
        )
        return(tbl)
    }

    ## extract relations from sheet structure
    parent <- lapply(
        seq_len(length(name) / 16L - 1L),
        \(i) seq(1, 16, by = 16/(2**i))
    )
    child_row <- rep(seq_along(parent), lengths(parent))
    parent_row <- child_row + 1L
    child <- c(
        list(c(1L, 1L)),
        lapply(head(parent, - 1), \(j) rep(j, each = 2))
    )
    child_parent_map <- tibble(
        child_row, parent_row,
        child = unlist(child),
        parent = unlist(parent)
    )

    ## all person names on this sheet
    person <- key[!is.na(name)]

    ## all relation nodes on this sheet
    relation_key <- function(x) {
        paste0(x[,1], "-", x[,2])
    }
    relation <-
        key[as.matrix(select(child_parent_map, parent_row, parent))] |>
        matrix(ncol = 2, byrow = TRUE, ) |>
        relation_key()

    ## 'child-of' edges
    child_index <-
        select(child_parent_map, child_row, child) |>
        as.matrix()
    child <- key[child_index][c(TRUE, FALSE)]
    child_of <- tibble(person = child, edge_label = "child-of", relation)

    ## 'partner-of' edges
    partner <-
        key[as.matrix(select(child_parent_map, parent_row, parent))]
    partner_of <- tibble(
        person = partner,
        edge_label = "partner-of",
        relation = rep(relation, each = 2)
    )

    tbl <- bind_rows(child_of, partner_of)
    bind_cols(key = uid(nrow(tbl)), tbl) |>
        filter(!is.na(person) & !relation == "NA-NA")
}

sheet_data <-
    function(sheet_id, sheet_name, row_index)
{
    sheet <- read_sheet(
        sheet_id, sheet_name, range = "B:Q",
        col_names = LETTERS[2:17], col_types = "c"
    )
    offsets <- setNames(0:4, c("name", "date", "place", "siblings", "notes"))

    if (length(row_index)) {
        individuals <-
            lapply(offsets, function(offset, sheet, idx) {
                filter(sheet, row_number() %in% (idx + offset)) |>
                    unlist()
            }, sheet, row_index)
    } else {
        individuals <- setNames(
            rep(list(character()), length(offsets)),
            names(offsets)
        )
    }

    ## unique identifiers
    name <- individuals$name
    tkey <- t(matrix(name, ncol = 16))
    tkey[!is.na(tkey)] <- uid(sum(!is.na(tkey)))
    key <- t(tkey)
    individuals <- c(list(key = as.vector(key)), individuals)

    ## person nodes
    p_nodes <-
        individuals |>
        as_tibble() |>
        filter(!is.na(name)) |>
        mutate(
            tab = sheet_name,
            tab_row = row_number()
        )

    ## edges
    edges <- find_edges(name, key)

    ## relationship nodes
    r_nodes <-
        edges |>
        select(relation) |>
        distinct()
    r_nodes <- bind_cols(key = uid(nrow(r_nodes)), r_nodes)

    ## update edge with person and relationship node keys
    if (NROW(edges)) {
        edges <-
            edges |>
            left_join(r_nodes, by = "relation") |>
            select(
                key = key.x,
                source = person,
                target = key.y,
                edge_label
            )
    } else {
        edges <- tibble(
            key = character(),
            source = character(),
            target = character(),
            edge_label = character()
        )
    }

    list(p_nodes = p_nodes, r_nodes = r_nodes, edges = edges)
}

row_indexes <- setNames(
    list(
        c(1, 5, 10, 17, 24),
        c(1, 8, 15, 22, 29),
        c(1, 8, 15, 22, 29),
        c(1, 8, 14, 20, 27),
        c(1, 8, 15),
        c(1, 7, 13, 19, 25),
        c(1),
        c(1, 7),
        c(1, 7, 13),
        c(1, 7, 14, 21, 27),
        c(1, 7),
        c(1, 8, 15, 22),
        c(1, 7, 14, 21, 27),
        c(1, 7, 13, 19),
        c(1, 7, 13, 19, 25),
        c(1, 7),
        c(1, 7),
        integer(),
        c(1, 7, 13, 19, 25),
        c(1, 7)
    ),
    sheet_names
)


edges_and_nodes <- Map(
    sheet_data,
    sheet_names, row_indexes,
    MoreArgs = list(sheet_id = sheet_id)
)

p_nodes <-
    Map(\(x) x[["p_nodes"]], edges_and_nodes) |>
    bind_rows()
r_nodes <-
    Map(\(x) x[["r_nodes"]], edges_and_nodes) |>
    bind_rows()
edges <-
    Map(\(x) x[["edges"]], edges_and_nodes) |>
    bind_rows()

## merge records spanning pages

merge_key_map <-
    function(row_indexes, p_nodes)
{
    merge_links <- Map(\(tab_name, indexes) {
        message(tab_name)
        if (length(indexes) < 2L) {
            return(character())
        }
        row_number <- as.integer(tail(indexes, 1) + 1L)
        range <- paste0("B", row_number, ":Q", row_number)
        cells <- range_read_cell(sheet_id, tab_name, range, cell_data = "full")
        name <- vapply(pull(cells, cell), \(x) {
            name <- x[["formattedValue"]]
            if (is.null(name))
                return(NA_character_)
            name
        }, character(1))
        link <- vapply(pull(cells, cell), \(x) {
            link <- x[["hyperlink"]]
            if (is.null(link))
                return(NA_character_)
            gid <- sub("#gid=", "", link)
            properties |>
                filter(id == gid) |>
                pull(name)
        }, character(1))
        tibble(from_tab = tab_name, from_name = name, to_tab = link)
    }, names(row_indexes), unname(row_indexes))


    merge_links <-
        merge_links[lengths(merge_links) > 0] |>
        bind_rows() |>
        filter(!is.na(to_tab))

    from_key <-
        merge_links |>
        left_join(p_nodes, by = c(from_tab = "tab", from_name = "name")) |>
        ## when more than one name matches (i.e., 'Benjamin Trigg'),
        ## choose last matching entry in sheet
        group_by(to_tab) |> filter(tab_row == max(tab_row)) |> ungroup() |>
        select(from_key = key)

    to_key <-
        merge_links |>
        left_join(filter(p_nodes, tab_row == 1), by = c(to_tab = "tab")) |>
        select(to_key = key)

    merge_keys <- bind_cols(from_key, to_key)

    setNames(
        pull(merge_keys, from_key),
        pull(merge_keys, to_key)
    )
}

key_map <- merge_key_map(row_indexes, p_nodes)

tibble(from_key = names(key_map), to_key = unname(key_map)) |>
    left_join(
        select(p_nodes, key, from_name = name),
        by = c(from_key = "key")
    ) |>
    left_join(
        select(p_nodes, key, to_name = name),
        by = c(to_key = "key")
    )

edges <-
    edges |>
    mutate(
        source = if_else(
            source %in% names(key_map),
            key_map[source],
            source
        )
    )

s_nodes <-
    p_nodes |>
    filter(key %in% names(key_map)) |>
    mutate(synonym_of = key_map[key])

p_nodes <-
    p_nodes |>
    filter(!key %in% names(key_map))

## clean up specific nodes

clean_siblings <-
    function(x)
{
    x <- sub("Siblings:[[:space:]]*", "", x)
    ifelse(nzchar(x), x, NA_character_)
}

p_nodes <-
    p_nodes |>
    mutate(
        siblings = case_match(
            key,
            "0002" ~ notes,
            "0003" ~ notes,
            .default = siblings
        ),
        notes = case_match(
            key,
            "0002" ~ NA_character_,
            "0003" ~ NA_character_,
            .default = notes
        ),
        siblings = clean_siblings(siblings)
    )

## convert to JSON graph structure
as_json <-
    function(p_nodes, s_nodes, r_nodes, edges, encrypted = FALSE)
{       
    if (encrypted) {
        node_query_fmt <- '[].{
            "key": key,
             "attributes": {
                "which": `"%s"`,
                "name": name,
                "date": date,
                "place": place,
                "siblings": siblings,
                "notes": notes
             }
          }'
    } else {
        node_query_fmt <- '[].{
            "key": key,
             "attributes": {
                "which": `"%s"`,
                "name": key
             }
          }'
    }
    r_node_query_fmt <- '[].{
        "key": key,
        "attributes": {
            "which": `"relation_node"`,
            "relation": relation
        }
    }'
    edge_query_fmt <- '[].{
        "key": key,
        "source": source,
        "target": target,
        "attributes": {
            "label": edge_label
        }
    }'
    graph_fmt <- '{
        "nodes": %s,
        "edges": %s
    }'
            
    json_p_nodes <-
        jsonlite::toJSON(p_nodes) |>
        rjsoncons::j_query(sprintf(node_query_fmt, "person_node"))

    json_s_nodes <-
        jsonlite::toJSON(s_nodes) |>
        ## FIXME: include synonym_of
        rjsoncons::j_query(sprintf(node_query_fmt, "synonym_node"))

    json_r_nodes <-
        jsonlite::toJSON(r_nodes) |>
        rjsoncons::j_query(r_node_query_fmt)

    json_edges <-
        jsonlite::toJSON(edges) |>
        rjsoncons::j_query(edge_query_fmt)

    ## hack graph object description

    ## combind person, synonym, and relationship nodes
    json_nodes <-
        paste0(json_p_nodes, json_s_nodes, json_r_nodes) |>
        gsub("][", ",", x = _, fixed = TRUE)
    ## assemble nodes and edges
    json_graph <- sprintf(graph_fmt, json_nodes, json_edges)

    if (encrypted) {
        salt <- sodium::random(32)
        print(salt)
        key <- sodium::scrypt(charToRaw(password), salt)
        print(key)
        msg <- charToRaw(json_graph)
        encrypted_graph <- sodium::data_encrypt(msg, key)
        ## tag <- sodium::data_tag(msg, key)
        writeBin(
            c(salt, attr(encrypted_graph, "nonce"), encrypted_graph),#, tag),
            "../static/unc_graph.json.enc"
        )
    } else {
        writeLines(json_graph, "../src/routes/unc_graph.json")
    }
}

as_json(p_nodes, s_nodes, r_nodes, edges, encrypted = FALSE)
as_json(p_nodes, s_nodes, r_nodes, edges, encrypted = TRUE)
