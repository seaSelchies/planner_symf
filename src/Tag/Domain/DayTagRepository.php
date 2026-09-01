<?php

namespace App\Tag\Domain;

interface DayTagRepository
{
    /**
     * @throws DayTagAlreadyExistsException if a row already exists for this (userId, date, tag)
     */
    public function create(string $userId, string $date, string $tag, ?string $notes): void;

    /**
     * @throws DayTagNotFoundException if no row with this id belongs to this user
     */
    public function updateNotes(string $userId, string $id, ?string $notes): void;

    /**
     * @throws DayTagNotFoundException if no row with this id belongs to this user
     */
    public function delete(string $userId, string $id): void;
}
