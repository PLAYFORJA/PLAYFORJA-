# PLAYFORJA — Forjá tu leyenda

Plataforma gamer para Latinoamérica. Competencias, salas, progresión y comunidad. **La economía interna no representa dinero real.**

## Accesos
- Sitio: https://playforja.github.io/PLAYFORJA-/
- Comunidad oficial: https://playforja.github.io/PLAYFORJA-/comunidad.html
- Repositorio: https://github.com/PLAYFORJA/PLAYFORJA-

## Infraestructura actual
- Frontend estático publicado desde la rama `main` mediante GitHub Pages.
- Supabase administrado para PostgreSQL, Auth y Storage.
- El navegador utiliza una clave publishable; no se incluye una clave `service_role`.
- El proyecto Supabase está activo en la región `us-east-2`.

> Esto todavía no es infraestructura autohospedada: GitHub Pages y Supabase son servicios administrados. La migración a servidores propios requiere contratar/configurar cómputo, dominio, backups, observabilidad y despliegue.

## Funciones implementadas
- Registro, inicio y cierre de sesión con Supabase Auth.
- Perfil de jugador y billetera PF/XP.
- Torneos: lectura, filtros por plataforma e inscripción transaccional.
- Salas: creación y unión mediante funciones SQL.
- Catálogo y canje de marcos con saldo PF.
- Ranking público.
- Comunidad PLAYFORJA: canal oficial, publicaciones, seguimiento, reacciones y conteos agregados.
- Primer pack de arte vectorial propio: yunque, llama, corona, meme GG y sticker animado Modo Forja.
- Políticas RLS en las tablas nuevas de comunidad.
- Funciones privilegiadas trasladadas a un esquema privado; las funciones públicas actúan como wrappers de invocación segura.

## Economía actual y decisiones pendientes
La base existente acredita **500 PF y 0 XP** al registrarse. La implementación actual solo tiene una columna de moneda PF. El diseño de tres monedas (oro, diamante y morada) todavía necesita que se definan sus nombres definitivos, equivalencias, precios y reglas antes de migrar billeteras o canjes. No se deben inventar valores ni alterar saldos existentes.

## Pendientes de producto y producción
1. Implementar las tres monedas PF/tipos de moneda con reglas y conversión aprobadas.
2. Crear archivos GIF reales optimizados, biblioteca de memes y flujo de carga multimedia; el primer sticker animado actual es SVG, no un GIF.
3. Herramientas de moderación, denuncias, bloqueo y controles antispam para la comunidad.
4. Cuenta oficial operativa con permisos de administración y publicaciones oficiales verificadas.
5. Validación de resultados, evidencias y acreditación de XP con auditoría.
6. Subida segura de imágenes y videos, límites de tamaño y moderación.
7. Panel administrativo para torneos, temporadas, recompensas y soporte.
8. Pruebas automatizadas de registro, sesiones, RLS, inscripciones, salas y canjes.
9. Plan de infraestructura autohospedada, backups, dominio propio, monitoreo y recuperación ante fallos.
10. Traducciones, streaming y empaquetado móvil.

## Seguridad y verificación
- Las tablas de comunidad tienen RLS y permisos explícitos.
- Los usuarios solo pueden modificar sus publicaciones, reacciones y seguimientos.
- Los conteos públicos de reacciones no exponen identidades.
- El asesor de seguridad de Supabase quedó sin hallazgos después de trasladar las funciones SECURITY DEFINER al esquema privado.
- Los avisos de índices sin uso son informativos en esta etapa; todavía no existe tráfico suficiente para medirlos.

## Desarrollo
Los archivos principales son `index.html`, `comunidad.html`, `assets/playforja-backend.js`, `assets/playforja-app.js`, `assets/community.js` y `assets/playforja.css`. Los cambios de base de datos están registrados en `supabase/migrations/`.
