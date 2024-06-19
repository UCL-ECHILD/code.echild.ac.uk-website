# SUBDOMAIN.echild.ac.uk website (Quarto template)

Template repo for the ECHILD SUBDOMAIN (Quarto) websites at <https://SUBDOMAIN.echild.ac.uk>.

## SETUP

To use this template:

-   Remove/replace all instances of `SUBDOMAIN` across repo 
-   Add content/images/favicons/etc.
-   Update renv.lock file (see [R renv documentation](https://rstudio.github.io/renv/articles/renv.html))
-   Update pyproject.toml (see [Python Poetry documentation](https://python-poetry.org/docs/basic-usage/))
-   Create SUBDOMAIN pages project (Workers & Pages > Create [button] > Pages > Upload assets [button])
-   Add DNS CNAME record for SUBDOMAIN (Workers & Pages > SUBDOMAIN Pages project > Custom Domains)
-   Edit Cloudflare Bulk Redirect list (so SUBDOMAIN.pages.dev -> SUBDOMAIN.echild.ac.uk)
-   Remove this SETUP section from this README
-   Uncomment lines 4-6 in `.github/workflows/publish.yml`
