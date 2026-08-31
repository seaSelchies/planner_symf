<?php

declare(strict_types=1);

/**
 * Self-check for the /entity step: does every mapping this module declares actually become a
 * column definition?
 *
 *     php .claude/skills/entity/verify-mapping.php <Module>
 *
 * It runs with NO database and with NO entry in config/packages/doctrine.yaml. Both are outside
 * this step's reach — the mapping section is a human's edit and the connection is a human's call —
 * and a check that needs a human's edit before it can run is a check that never runs. So the
 * metadata is loaded straight from the attributes on the classes, and the DDL is rendered against
 * PostgreSQLPlatform directly.
 *
 * SchemaTool is deliberately not used: it asks the connection for current_schema() before it
 * generates anything, which puts a live database back in the way.
 *
 * What a zero exit proves: every field mapping can be turned into a column definition. What it does
 * not prove: that the schema matches the real database, that a query returns rows, or that the
 * associations are the right ones. Those need a running database and belong to /cover and /build.
 *
 * Exit 0 and print the DDL when every mapping renders; exit 1 naming the class, the field and the
 * exception when one does not.
 */

require __DIR__ . '/../../../vendor/autoload.php';

use Doctrine\DBAL\DriverManager;
use Doctrine\DBAL\Platforms\PostgreSQLPlatform;
use Doctrine\DBAL\Schema\Table;
use Doctrine\DBAL\Types\Type;
use Doctrine\ORM\EntityManager;
use Doctrine\ORM\ORMSetup;

$module = $argv[1] ?? null;

if ($module === null || $module === '') {
    fwrite(STDERR, "usage: php .claude/skills/entity/verify-mapping.php <Module>\n");
    exit(2);
}

$root = dirname(__DIR__, 3);
$dir  = $root . '/src/' . $module . '/Domain';

if (!is_dir($dir)) {
    fwrite(STDERR, sprintf("no such directory: %s — is %s the module name?\n", $dir, $module));
    exit(2);
}

$config = ORMSetup::createAttributeMetadataConfiguration([$dir], true);

// Without native lazy objects the EntityManager constructor throws on this PHP/ORM combination,
// before a single mapping has been looked at. Enable it where the installed ORM offers it.
if (method_exists($config, 'enableNativeLazyObjects')) {
    $config->enableNativeLazyObjects(true);
}

// pdo_pgsql with an explicit serverVersion: nothing connects, and nothing dials out to ask the
// server what version it is.
$connection = DriverManager::getConnection(
    ['driver' => 'pdo_pgsql', 'serverVersion' => '16'],
    $config,
);

$em       = new EntityManager($connection, $config);
$platform = new PostgreSQLPlatform();

$allMetadata = $em->getMetadataFactory()->getAllMetadata();

if ($allMetadata === []) {
    fwrite(STDERR, sprintf("no entity found under %s\n", $dir));
    exit(1);
}

$failures = 0;

foreach ($allMetadata as $metadata) {
    printf("%s -> %s\n", $metadata->getName(), $metadata->getTableName());

    $table = new Table($metadata->getTableName());

    foreach ($metadata->fieldMappings as $fieldName => $mapping) {
        try {
            $column = $table->addColumn($mapping->columnName, $mapping->type);

            $column->setNotnull(!($mapping->nullable ?? false));

            if ($mapping->length !== null) {
                $column->setLength($mapping->length);
            }

            // Column::setScale() takes an int, and the platform refuses a decimal declaration with
            // no precision — so a mapping that says `decimal` and declares neither fails HERE,
            // which is exactly what this script exists to catch.
            if ($mapping->precision !== null || $mapping->scale !== null || $mapping->type === 'decimal') {
                $column->setPrecision($mapping->precision);
                $column->setScale($mapping->scale);
            }

            $default = $mapping->options['default'] ?? $mapping->default;

            if ($default !== null) {
                $column->setDefault($default);
            }

            // A type name nothing is registered for is a mapping that cannot become a column.
            Type::getType($mapping->type);
        } catch (\Throwable $e) {
            ++$failures;
            printf(
                "  FAILED %s::\$%s (column %s, type %s): %s: %s\n",
                $metadata->getName(),
                $fieldName,
                $mapping->columnName,
                $mapping->type,
                $e::class,
                $e->getMessage(),
            );
        }
    }

    try {
        foreach ($platform->getCreateTableSQL($table) as $sql) {
            printf("  %s\n", $sql);
        }
    } catch (\Throwable $e) {
        ++$failures;
        printf(
            "  FAILED %s (table %s) could not be rendered: %s: %s\n",
            $metadata->getName(),
            $metadata->getTableName(),
            $e::class,
            $e->getMessage(),
        );
    }
}

if ($failures > 0) {
    fwrite(STDERR, sprintf("\n%d mapping(s) could not be rendered as a column definition.\n", $failures));
    exit(1);
}

printf("\nall %d entities render as column definitions.\n", count($allMetadata));
exit(0);
