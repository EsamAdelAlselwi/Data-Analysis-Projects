/*
COVID-19 Data Exploration Project
Analyst: [EsamAdelAlselwi ]
Tools Used: SQL (Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views)
*/

-- 1. Initial Data Exploration: Reviewing the basic structure and fields
SELECT continent, location, total_cases 
FROM coviddeaths 
WHERE continent IS NOT NULL AND continent != ' ' 
ORDER BY new_cases DESC;

-- 2. Data Cleaning: Converting empty continent values to NULL for accurate analysis
UPDATE coviddeaths
SET continent = NULL
WHERE continent = ' ';

-- 3. Global Overview: Total countries, date range, and global cases/deaths
SELECT 
    COUNT(DISTINCT location) AS Number_of_Countries,
    MIN(date) AS First_Date,
    MAX(date) AS Last_Date,
    SUM(CAST(new_cases AS decimal)) AS Total_Cases_Global,
    SUM(CAST(new_deaths AS decimal)) AS Total_Deaths_Global
FROM CovidDeaths
WHERE continent IS NOT NULL;

-- 4. Top 10 Countries by Total Infections and Infection Rate relative to Population
SELECT
    location,
    MAX(CAST(total_cases AS decimal)) AS Highest_Infection_Count,
    MAX(CAST(population AS decimal)) AS Population,
    (MAX(CAST(total_cases AS decimal)) * 100.0 / MAX(population)) AS Percent_Population_Infected
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY Highest_Infection_Count DESC
LIMIT 10;

-- 5. Top 10 Countries by Total Death Count
SELECT 
    location,
    MAX(CAST(total_deaths AS decimal)) AS Total_Death_Count
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location 
ORDER BY Total_Death_Count DESC
LIMIT 10;

-- 6. Top 10 Countries by Case Fatality Rate (CFR)
-- Shows the likelihood of dying if you contract COVID-19 in these countries
SELECT 
    location,
    MAX(CAST(total_cases AS decimal)) AS Total_Cases,
    MAX(CAST(total_deaths AS decimal)) AS Total_Deaths,
    (MAX(CAST(total_deaths AS float)) / NULLIF(MAX(total_cases), 0)) * 100 AS Case_Fatality_Rate
FROM CovidDeaths
WHERE continent IS NOT NULL AND total_cases > 0
GROUP BY location
ORDER BY Case_Fatality_Rate DESC
LIMIT 10;

-- 7. Time Series Analysis: Daily trend of cumulative cases and deaths (Example: United States)
SELECT 
    `date`,
    new_cases,
    new_deaths,
    SUM(new_cases) OVER (ORDER BY `date`) AS Cumulative_Cases,
    SUM(new_deaths) OVER (ORDER BY `date`) AS Cumulative_Deaths
FROM CovidDeaths
WHERE location = 'United States' AND continent IS NOT NULL
ORDER BY `date`;

-- 8. 7-Day Rolling Average for New Cases to smooth out daily fluctuations
SELECT 
    location,
    `date`,
    new_cases,
    AVG(new_cases) OVER (PARTITION BY location ORDER BY `date` ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS Rolling_7Day_Avg_Cases
FROM CovidDeaths
WHERE location = 'United States' AND continent IS NOT NULL
ORDER BY date;

-- 9. Death Percentage Analysis for specific locations (Example: Yemen and US)
SELECT Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM CovidDeaths
WHERE (location LIKE 'yem%' OR location LIKE '%states%')
AND continent IS NOT NULL 
ORDER BY 1, 2;

-- 10. Cumulative Infection Rate relative to Population over time
SELECT Location, date, total_cases, population, (total_cases/population)*100 AS PopulationInfectedPercentage
FROM CovidDeaths
WHERE location LIKE '%states%' AND continent IS NOT NULL 
ORDER BY 1, 2;

-- 11. Countries with Highest Infection Rate compared to Population (Comprehensive)
SELECT Location, Population, MAX(total_cases) AS HighestInfectionCount, MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM CovidDeaths
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC;

-- 12. Continent-level Analysis: Total Death Count per Continent
SELECT continent, MAX(CAST(Total_deaths AS decimal)) AS TotalDeathCount
FROM CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY continent
ORDER BY TotalDeathCount DESC;

-- 13. Population vs. Vaccinations: Calculating the rolling sum of vaccinated people
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS decimal)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM CovidDeaths dea
JOIN CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL 
ORDER BY 2, 3;

-- 14. Using CTE to calculate the percentage of population vaccinated based on the rolling sum
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated) AS (
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS decimal)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
    FROM CovidDeaths dea
    JOIN CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccinated/Population)*100 AS PercentPopulationVaccinated
FROM PopvsVac;

-- 15. Using a Temp Table to store vaccination data for further calculations
DROP TABLE IF EXISTS PercentPopulationVaccinated;
CREATE TABLE PercentPopulationVaccinated (
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

INSERT INTO PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS decimal)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM CovidDeaths dea
JOIN CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

SELECT *, (RollingPeopleVaccinated/Population)*100 AS PercentPopulationVaccinated
FROM PercentPopulationVaccinated;

-- 16. Creating a View to store data for later visualizations (e.g., Tableau or Power BI)
CREATE VIEW PercentPopulationVaccinatedView AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS decimal)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM CovidDeaths dea
JOIN CovidVaccinations vac ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
