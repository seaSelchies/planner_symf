import { useCallback, useRef, useState } from 'react';
import { supabase } from '../../../../planner/src/lib/supabase';
import { DayTag } from '../../../../planner/src/types';

export type TagsByDate = Record<string, DayTag[]>;

export function useDayTags() {
  const [tagsByDate, setTagsByDate] = useState<TagsByDate>({});

  // Keep a ref so toggleTag / updateNote always see the latest state
  // without needing tagsByDate in their dependency arrays.
  const tagsRef = useRef<TagsByDate>({});

  const setTags = useCallback(
    (updater: TagsByDate | ((prev: TagsByDate) => TagsByDate)) => {
      setTagsByDate((prev) => {
        const next = typeof updater === 'function' ? updater(prev) : updater;
        tagsRef.current = next;
        return next;
      });
    },
    []
  );

  // ── Fetch ────────────────────────────────────────────────────
  const fetchTags = useCallback(
    async (dates: string[]) => {
      if (dates.length === 0) {
        setTags({});
        return;
      }
      const { data, error } = await supabase
        .from('day_tags')
        .select('*')
        .in('date', dates);
      if (error || !data) return;
      const map: TagsByDate = {};
      for (const t of data as DayTag[]) {
        (map[t.date] ??= []).push(t);
      }
      setTags(map);
    },
    [setTags]
  );

  // ── Toggle (add / remove) ────────────────────────────────────
  const toggleTag = useCallback(
    async (date: string, tagType: string) => {
      const existing = (tagsRef.current[date] ?? []).find(
        (t) => t.tag === tagType
      );

      if (existing) {
        // Optimistic remove
        setTags((prev) => ({
          ...prev,
          [date]: (prev[date] ?? []).filter((t) => t.id !== existing.id),
        }));
        await supabase.from('day_tags').delete().eq('id', existing.id);
      } else {
        const {
          data: { user },
        } = await supabase.auth.getUser();
        if (!user) return;
        const { data, error } = await supabase
          .from('day_tags')
          .insert({ user_id: user.id, date, tag: tagType })
          .select()
          .single();
        if (!error && data) {
          setTags((prev) => ({
            ...prev,
            [date]: [...(prev[date] ?? []), data as DayTag],
          }));
        }
      }
    },
    [setTags]
  );

  // ── Update note ──────────────────────────────────────────────
  const updateNote = useCallback(
    async (id: string, notes: string | null) => {
      const { data, error } = await supabase
        .from('day_tags')
        .update({ notes: notes || null })
        .eq('id', id)
        .select()
        .single();
      if (!error && data) {
        const updated = data as DayTag;
        setTags((prev) => {
          const entries = prev[updated.date];
          if (!entries) return prev;
          return {
            ...prev,
            [updated.date]: entries.map((t) =>
              t.id === id ? updated : t
            ),
          };
        });
      }
    },
    [setTags]
  );

  // ── Upsert with notes (create or update) ────────────────────
  const upsertTag = useCallback(
    async (date: string, tagType: string, notes: string | null) => {
      const existing = (tagsRef.current[date] ?? []).find(
        (t) => t.tag === tagType
      );
      if (existing) {
        await updateNote(existing.id, notes);
      } else {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;
        const { data, error } = await supabase
          .from('day_tags')
          .insert({ user_id: user.id, date, tag: tagType, notes })
          .select()
          .single();
        if (!error && data) {
          setTags((prev) => ({
            ...prev,
            [date]: [...(prev[date] ?? []), data as DayTag],
          }));
        }
      }
    },
    [setTags, updateNote]
  );

  // ── Remove a specific tag ────────────────────────────────────
  const removeTag = useCallback(
    async (date: string, tagType: string) => {
      const existing = (tagsRef.current[date] ?? []).find(
        (t) => t.tag === tagType
      );
      if (!existing) return;
      setTags((prev) => ({
        ...prev,
        [date]: (prev[date] ?? []).filter((t) => t.id !== existing.id),
      }));
      await supabase.from('day_tags').delete().eq('id', existing.id);
    },
    [setTags]
  );

  return { tagsByDate, fetchTags, toggleTag, updateNote, upsertTag, removeTag };
}
