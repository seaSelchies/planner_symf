<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\DBAL\Schema\Table;
use Doctrine\Migrations\AbstractMigration;

final class Version20260722160749 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Create users table';
    }

    public function up(Schema $schema): void
    {
        $schemaManager = $this->connection->createSchemaManager();
        $users = new Table('users');
        $users->addColumn('id', 'integer', ['autoincrement' => true]);
        $users->addColumn('email', 'string', ['length' => 180]);
        $users->addColumn('name', 'string', ['length' => 180]);
        $users->addColumn('password_hash', 'string', ['length' => 255]);
        $users->addColumn('created_at', 'datetime_immutable');

        if (!$schemaManager->tableExists('users')) {
            $schemaManager->createTable($users);
        }


    }

    public function down(Schema $schema): void
    {
        $schemaManager = $this->connection->createSchemaManager();
        if ($schemaManager->tableExists('users')) {
            $schemaManager->dropTable('users');
        }
    }
}
