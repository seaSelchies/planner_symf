<?php

namespace App\Tag\Infrastructure\DB;

use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagDataFetchException;
use App\Tag\Domain\DayTagProvider;
use Doctrine\DBAL\ArrayParameterType;
use Doctrine\DBAL\Exception as DBALException;
use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\Exception\ORMException;

final class DoctrineDayTagProvider implements DayTagProvider
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
    ) {
    }

    public function tagsForDates(string $userId, array $dates): array
    {
        if ($dates === []) {
            return [];
        }

        try {
            return $this->entityManager->createQueryBuilder()
                ->select('t')
                ->from(DayTag::class, 't')
                ->where('t.userId = :userId')
                ->andWhere('t.date IN (:dates)')
                ->setParameter('userId', $userId)
                ->setParameter('dates', $dates, ArrayParameterType::STRING)
                ->getQuery()
                ->getResult();
        } catch (DBALException|ORMException $e) {
            throw new DayTagDataFetchException('Failed to fetch day tags.', previous: $e);
        }
    }

    public function findByUserDateTag(string $userId, string $date, string $tag): ?DayTag
    {
        try {
            return $this->entityManager->createQueryBuilder()
                ->select('t')
                ->from(DayTag::class, 't')
                ->where('t.userId = :userId')
                ->andWhere('t.date = :date')
                ->andWhere('t.tag = :tag')
                ->setParameter('userId', $userId)
                ->setParameter('date', $date)
                ->setParameter('tag', $tag)
                ->getQuery()
                ->getOneOrNullResult();
        } catch (DBALException|ORMException $e) {
            throw new DayTagDataFetchException('Failed to fetch a day tag.', previous: $e);
        }
    }
}
