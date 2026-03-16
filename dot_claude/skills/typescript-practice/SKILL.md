---
name: typescript-practice
description: TypeScript/React/Next.jsプロジェクトのコーディングベストプラクティスとツールチェーン設定。新規プロジェクトのセットアップやコード生成時に参照する。
user_invocable: false
---

# TypeScript ベストプラクティス

## 原則

- 標準ライブラリを外部依存より優先する
- クラスを避け、純粋関数とステート分離を推奨
- 関数は冪等に保つ
- 型安全性を最大限に活用する（any禁止、unknown推奨）

## パッケージマネージャ

package-lock.jsonが存在しない限り pnpm を使用:

```bash
pnpm install
pnpm add <package>
```

## バンドラ

- フロントエンド: vite
- ライブラリ: tsdown
- フルスタック: Next.js

## リンター

oxlint（Rust製、高速）を使用:

```bash
pnpm add -D oxlint
pnpm oxlint
```

設定例は `assets/oxlint.json` を参照。

## 実行

Node.js 24+ はTypeScriptを直接実行可能:

```bash
node foo.ts
```

## テスト

vitest を使用:

```bash
pnpm add -D vitest
```

```typescript
// foo.test.ts
import { expect, test } from 'vitest';
import { add } from './foo.ts';

test('add', () => {
  expect(add(1, 2)).toBe(3);
});
```

```bash
pnpm vitest
```

## コードスタイル

```typescript
// 推奨: 純粋関数 + ステート分離
type State = { count: number };

const increment = (state: State): State => ({
  ...state,
  count: state.count + 1,
});

// 非推奨: ミュータブルなクラス
class Counter {
  count = 0;
  increment() { this.count++; }
}
```

## 標準APIを優先

```typescript
// fetch（外部ライブラリ不要）
const res = await fetch(url);
const data = await res.json();

// crypto
const id = crypto.randomUUID();

// URL
const url = new URL('/path', base);

// structuredClone（ディープコピー）
const copy = structuredClone(original);
```

## React/Next.js 固有

### コンポーネント設計
- Server Components をデフォルトに、必要な場合のみ 'use client'
- Props は interface ではなく type で定義
- children の型は React.ReactNode

```typescript
type Props = {
  title: string;
  children: React.ReactNode;
};

export function Card({ title, children }: Props) {
  return (
    <div>
      <h2>{title}</h2>
      {children}
    </div>
  );
}
```

### 状態管理
- ローカル状態: useState / useReducer
- サーバー状態: React Query (TanStack Query) または SWR
- グローバル状態: 必要最小限にし、Context または Zustand

### データフェッチ
- Server Components で直接 fetch を使用（Next.js App Router）
- クライアントサイドは React Query を優先

```typescript
// Server Component でのデータ取得
async function UserList() {
  const users = await fetch('https://api.example.com/users').then(r => r.json());
  return <ul>{users.map(u => <li key={u.id}>{u.name}</li>)}</ul>;
}
```

### ディレクトリ構成（Next.js App Router）
```
src/
  app/          # ルーティング（layout, page, loading, error）
  components/   # 共有コンポーネント
  lib/          # ユーティリティ・APIクライアント
  types/        # 型定義
```
