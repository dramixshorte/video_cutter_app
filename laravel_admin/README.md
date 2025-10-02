# Laravel Admin (Modern Backend)

This directory contains a fresh Laravel-based admin panel and API intended to replace the legacy `App/api.php` procedural backend. It introduces a clean MVC structure, migrations, Eloquent models, services, Blade UI, and Firebase notification integration.

## Key Domains Mapped
- Series & Episodes management (CRUD, image upload placeholder, ordering, visibility)
- Settings (app config, multi-app keyed by `app_id` if needed)
- AdMob / Ads configuration
- Coin Packages & Purchases (packages definition table)
- VIP Packages
- Daily Gifts
- Users (basic management + soft deletes optional)
- Notifications (FCM broadcast + logs)
- Dashboard Statistics (aggregations for counts, sums, recent activity)

## Stack
- Laravel 11
- MySQL
- Tailwind CSS (to be added) + Blade templates
- Kreait Firebase SDK (via `kreait/laravel-firebase`)

## Setup
1. Install dependencies:
   composer install
2. Copy environment file and generate key:
   copy .env.example .env
   php artisan key:generate
3. Configure your database credentials in `.env`.
4. Place your Firebase service account JSON at `storage/firebase-service-account.json` and set `FIREBASE_CREDENTIALS` accordingly.
5. Run migrations:
   php artisan migrate
6. (Optional) Seed initial data:
   php artisan db:seed
7. Serve locally:
   php artisan serve

## Planned Tables
- users
- series
- episodes
- settings (key, value, app_id)
- coin_packages
- vip_packages
- daily_gifts
- notifications (logs)
- admob_configs

## Naming Conventions
- Controllers in `App/Http/Controllers/Admin`
- Services in `App/Services`
- View components in `resources/views/components`

## Next Steps
- Add migrations & models
- Implement controllers & routes
- Add Blade layout & navigation
- Implement Firebase notification dispatch service
- Integrate authentication (Laravel Breeze or Fortify) (optional - not yet included)

## Design & Theming
The admin uses custom CSS (`public/css/app.css`) with CSS variables aligned to the Flutter app dark theme:

Core variables:
- `--color-primary` / `--color-primary-accent`
- `--color-bg` / `--color-bg-alt`
- `--color-surface`
- `--color-text` / `--color-text-dim`

To customize:
1. Edit variables in `/public/css/app.css`.
2. Add new utility classes below the variable block.
3. (Optional) Switch to Tailwind by installing `laravel/vite-plugin` & Tailwind, then replace the handcrafted classes gradually.

RTL & Light Mode:
- Default direction is RTL (`<html dir="rtl">`).
- JS toggles for light/dark & LTR/RTL included in `layouts/app.blade.php`.

If you integrate full Laravel build tooling later, move inline `<script>` toggles into a dedicated asset bundle.

## Legacy Mapping Note
Each former `action` in `api.php` will map either to a RESTful controller method or a dedicated endpoint under a versioned API route group, improving clarity and maintainability.

## License
Internal project component.
