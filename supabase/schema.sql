-- コツコツバンク: 端末間データ同期用スキーマ
-- Supabase ダッシュボード → SQL Editor に貼り付けて Run してください。
-- 2回目以降に実行しても壊れないよう、すべて "if not exists" / "drop policy if exists" にしています。

-- =========================================================
-- テーブル
-- =========================================================

create table if not exists public.child_profiles (
    id                          uuid primary key,
    account_id                  uuid not null,
    name                        text not null default '',
    avatar_system_image         text not null default 'face.smiling.fill',
    color_hex                   text not null default 'FF6B00',
    avatar_image_data           text,
    background_color_hex        text not null default 'DCE9FF',
    empty_state_icon_name       text not null default 'sparkles',
    parent_turn_pending         boolean not null default false,
    last_level5_streak_trigger  integer not null default 0,
    parent_turn_task_title      text,
    created_at                  timestamptz not null default now(),
    updated_at                  timestamptz not null default now(),
    deleted_at                  timestamptz
);

create table if not exists public.goals (
    id           uuid primary key,
    account_id   uuid not null,
    child_id     uuid not null,
    title        text not null default '',
    price        double precision not null default 0,
    product_url  text,
    image_data   text,
    redeemed_at  timestamptz,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    deleted_at   timestamptz
);

create table if not exists public.missions (
    id                         uuid primary key,
    account_id                 uuid not null,
    child_id                   uuid not null,
    title                      text not null default '',
    reward                     double precision not null default 0,
    reward_unit_raw            text not null default 'perTask',
    category_raw               text not null default 'chores',
    status_raw                 text not null default 'pending',
    due_date                   timestamptz,
    completed_at               timestamptz,
    timer_accumulated_seconds  double precision not null default 0,
    timer_started_at           timestamptz,
    photo_data                 text,
    comment                    text,
    parent_feedback            text,
    celebration_played         boolean not null default false,
    preset_icon_name           text,
    created_at                 timestamptz not null default now(),
    updated_at                 timestamptz not null default now(),
    deleted_at                 timestamptz
);

-- =========================================================
-- インデックス(同期は account_id + updated_at で引く)
-- =========================================================

create index if not exists idx_child_profiles_account on public.child_profiles (account_id, updated_at);
create index if not exists idx_goals_account          on public.goals (account_id, updated_at);
create index if not exists idx_missions_account       on public.missions (account_id, updated_at);

-- =========================================================
-- 行レベルセキュリティ: 自分(ログイン中のアカウント)の行だけ読み書きできる
-- account_id は Supabase Auth のユーザーID(= アプリの FamilyAccount.id)
-- =========================================================

alter table public.child_profiles enable row level security;
alter table public.goals          enable row level security;
alter table public.missions       enable row level security;

drop policy if exists "own child_profiles" on public.child_profiles;
create policy "own child_profiles" on public.child_profiles
    for all
    using (account_id = auth.uid())
    with check (account_id = auth.uid());

drop policy if exists "own goals" on public.goals;
create policy "own goals" on public.goals
    for all
    using (account_id = auth.uid())
    with check (account_id = auth.uid());

drop policy if exists "own missions" on public.missions;
create policy "own missions" on public.missions
    for all
    using (account_id = auth.uid())
    with check (account_id = auth.uid());
