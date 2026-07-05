# Data Sources — Healthcare Capacity Constraints for Chile

All files originate from MINSAL (Ministry of Health, Chile) via the DEIS (Departamento de Estadísticas e Información de Salud) and are covered by a collaboration agreement with the Ministry of Health (see `docs/0_PropuestaCompleta.pdf`, support letter annex).

**Indicator definitions:** See `docs/analisis_presion_hospitalaria_cancer.docx` for the authoritative specification of all capacity and quality measures constructed from these files.

---

## Monthly Hospital Statistics (Estadísticas Hospitalarias)

| File | Coverage | Primary Use |
|------|----------|-------------|
| `Consolidado Estadísticas Hospitalarias 2014-2023.xlsx` | Jan 2014 – Dec 2023 | Main panel: admissions, discharges, occupied bed-days, deaths by hospital and clinical service |
| `Estadísticas Hospitalarias Octubre 2024.xlsx` | Oct 2024 | Extends main panel into 2024 |
| `Estadísticas Hospitalarias Noviembre 2025.xlsx` | Nov 2025 | Extends main panel into 2025 |

**Key variables (typical):** establishment code, clinical service (`servicio_clinico`), level of care (`nivel_cuidado`), month/year, total admissions (`egresos`), occupied bed-days (`dias_cama_ocupados`), available bed-days (`dias_cama_disponibles`), deaths (`fallecidos`).

Reference standard for variable definitions: `Norma-820.-Estándares-de-Información-de-Salud.pdf`.

---

## Bed Capacity (Dotación de Camas)

| File | Coverage | Primary Use |
|------|----------|-------------|
| `Dotación de camas 2010-2025 Establecimientos Pertenecientes al SNSS_01-12-2025.xlsx` | 2010–2025, SNSS (public network) | Denominator for occupancy rate: authorized beds by hospital and service |
| `Dotación de camas 2019-2025 Establecimientos No pertenecientes al SNSS.xlsx` | 2019–2025, non-SNSS (private) | Private-sector bed complement |

**Key variables (typical):** establishment code, clinical service, year, authorized beds (`camas_autorizadas`), operational beds (`camas_en_operación`).

---

## Reference / Crosswalk Files

| File | Description | Use |
|------|-------------|-----|
| `Establecimientos DEIS MINSAL 20-08-2024.xlsx` | Hospital and facility registry (DEIS, Aug 2024) | Crosswalk: establishment codes → names, regions, SNSS membership, complexity level |
| `Niveles_Cuidado.xlsx` | Levels-of-care classification | Map clinical services to care level (basic, medium, high, critical) |
| `Servicio_Clinico.xlsx` | Clinical service codes | Harmonize service codes across years and data sources |

---

## Reference Document

| File | Description |
|------|-------------|
| `Norma-820.-Estándares-de-Información-de-Salud.pdf` | MINSAL Norma 820 — official standards for health information variables. Reference for all variable definitions and coding conventions. |

---

## Notes

- Data files are large and may be gitignored depending on your setup. Check `.gitignore` and add `data/*.xlsx` / `data/*.pdf` if you do not want to commit raw data.
- Always load data via `scripts/R/01_load.R` using `here::here("data", "filename.xlsx")` — never hardcode absolute paths.
- The monthly statistics files have minor structural differences across years; harmonization logic lives in `scripts/R/02_clean.R`.
