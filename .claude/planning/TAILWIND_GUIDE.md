# Tailwind CSS Pro - Vodič za korišćenje

Projekat je konfigurisan sa Tailwind CSS Pro feature-ima. Svi view-ovi treba da se kreiraju koristeći Tailwind CSS klase.

## Pokretanje development servera

```bash
bin/dev
```

Ova komanda će pokrenuti:
- Rails server na portu 3000
- Tailwind CSS watch mode (automatski rebuild CSS fajlova)

## Build CSS za produkciju

```bash
npm run build:css
```

## Dostupni Pro Feature-i

### 1. Custom Color Palette

```erb
<!-- Primary colors -->
<div class="bg-primary-600 text-white">Primary button</div>
<div class="bg-primary-100 text-primary-800">Light primary</div>

<!-- Accent colors -->
<div class="bg-accent text-white">Accent color</div>
<div class="bg-accent-dark">Dark accent</div>
```

### 2. Custom Button Components

```erb
<!-- Pre-styled buttons -->
<button class="btn-primary">Primary Button</button>
<button class="btn-secondary">Secondary Button</button>
<button class="btn-accent">Accent Button</button>
<button class="btn-glow">Glowing Button</button>
```

### 3. Card Components

```erb
<!-- Standard card -->
<div class="card">
  <h3>Card title</h3>
  <p>Card content</p>
</div>

<!-- Glass morphism card -->
<div class="card-glass">
  <h3>Glass card</h3>
</div>

<!-- Neumorphic card -->
<div class="card-neumorphic">
  <h3>Neumorphic style</h3>
</div>
```

### 4. Badge Components

```erb
<span class="badge-primary">Primary</span>
<span class="badge-success">Success</span>
<span class="badge-warning">Warning</span>
<span class="badge-danger">Danger</span>
```

### 5. Custom Animations

```erb
<!-- Fade in animation -->
<div class="animate-fade-in">Fades in on load</div>

<!-- Fade in and up -->
<div class="animate-fade-in-up">Slides up on load</div>

<!-- Slide in from left -->
<div class="animate-slide-in">Slides in</div>

<!-- Wiggle animation -->
<div class="animate-wiggle">Wiggles</div>

<!-- Slow bounce -->
<div class="animate-bounce-slow">Bounces slowly</div>
```

### 6. Hover Effects

```erb
<!-- Lift on hover -->
<div class="card hover-lift">Lifts on hover</div>

<!-- Scale on hover -->
<div class="hover-scale">Scales on hover</div>

<!-- Rotate on hover -->
<div class="hover-rotate">Rotates on hover</div>
```

### 7. Glass Morphism

```erb
<!-- Glass effect -->
<div class="glass p-6 rounded-2xl">
  Glass morphism background
</div>

<!-- Dark glass -->
<div class="glass-dark p-6 rounded-2xl">
  Dark glass effect
</div>
```

### 8. Gradient Text

```erb
<h1 class="gradient-text text-5xl">
  Gradient colored text
</h1>
```

### 9. Custom Shadows

```erb
<!-- Glow effect -->
<div class="shadow-glow">Glowing shadow</div>
<div class="shadow-glow-lg">Large glow</div>

<!-- Inner glow -->
<div class="shadow-inner-glow">Inner glow</div>

<!-- Neumorphic shadow -->
<div class="shadow-neumorphic">Neumorphic effect</div>
```

### 10. Input Components

```erb
<!-- Standard input -->
<input type="text" class="input" placeholder="Enter text">

<!-- Input with glow on focus -->
<input type="text" class="input-glow" placeholder="Glows on focus">
```

### 11. Text Utilities

```erb
<!-- Text shadow -->
<h1 class="text-shadow">Text with shadow</h1>
<h1 class="text-shadow-lg">Large text shadow</h1>

<!-- Balanced text wrapping -->
<p class="text-balance">Text with balanced wrapping</p>
```

### 12. Custom Spacing

```erb
<div class="space-y-72">Large spacing (18rem)</div>
<div class="space-y-84">Larger spacing (21rem)</div>
<div class="space-y-96">XL spacing (24rem)</div>
<div class="space-y-128">XXL spacing (32rem)</div>
```

### 13. Dark Mode Support

Dark mode je konfigurisan sa `class` strategijom:

```erb
<!-- Različiti stilovi za light i dark mode -->
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
  Content that adapts to dark mode
</div>
```

Da bi aktivirali dark mode, dodajte `dark` klasu na `<html>` element.

## Responsive Design

Svi Tailwind breakpoint-i su dostupni:

- `sm:` - 640px i više
- `md:` - 768px i više
- `lg:` - 1024px i više
- `xl:` - 1280px i više
- `2xl:` - 1536px i više

```erb
<div class="text-sm md:text-base lg:text-lg xl:text-xl">
  Responsive text size
</div>
```

## Tailwind CSS Plugins

Projekat uključuje sledeće Tailwind CSS plugine:

1. **@tailwindcss/forms** - Lepši stilovi za forme
2. **@tailwindcss/typography** - Typography plugin za prose content
3. **@tailwindcss/aspect-ratio** - Aspect ratio utilities

### Typography Plugin primer

```erb
<article class="prose lg:prose-xl">
  <h1>Article title</h1>
  <p>Article content with automatic beautiful typography...</p>
</article>
```

## Primeri

Pogledajte `app/views/pages/index.html.erb` za kompletan primer korišćenja Tailwind CSS Pro feature-a.

## Tips

1. **Koristite custom komponente**: Umesto ponavljanja klasa, koristite `.btn-primary`, `.card`, itd.
2. **Kombinujte animacije**: Možete kombinovati više animation klasa
3. **Responsive first**: Počnite sa mobile dizajnom, pa dodajte md:, lg: klase
4. **Dark mode**: Uvek razmislite o dark mode varijanti
5. **Compose utilities**: Kombinujte basic Tailwind utilities sa custom komponentama

## Dokumentacija

- [Tailwind CSS dokumentacija](https://tailwindcss.com/docs)
- [Tailwind CSS Forms](https://github.com/tailwindlabs/tailwindcss-forms)
- [Tailwind CSS Typography](https://tailwindcss.com/docs/typography-plugin)

## Struktura fajlova

- `tailwind.config.js` - Tailwind konfiguracija sa custom theme
- `app/assets/stylesheets/application.tailwind.css` - Custom komponente i utilities
- `app/assets/builds/application.css` - Compiled CSS (ne editovati ručno)
- `Procfile.dev` - Development process manager config
- `bin/dev` - Script za pokretanje development servera sa CSS watch-om
