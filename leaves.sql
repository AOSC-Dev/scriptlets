-- Run it on the repo server
-- Requires R/O permission on the meta database of the packages-site
SELECT DISTINCT name
FROM v_packages
WHERE branch = 'stable'
AND name NOT IN (
	SELECT DISTINCT dependency
	FROM package_dependencies
	WHERE relationship IN ('PKGDEP', 'BUILDDEP', 'PKGRECOM', 'PKGSUG')
)
ORDER BY name;
