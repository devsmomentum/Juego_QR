# 🎮 MapHunter (Juego QR) v2.2

**Real Life RPG - Búsqueda del Tesoro Interactiva**

Juego de rol en la vida real ("Real World RPG") que combina búsqueda de pistas físicas mediante QR, minijuegos móviles y sabotajes entre jugadores en tiempo real, gestionado por un panel de administración centralizado.

---

## 🚀 Estado Actual (v2.1)

**¡Robustez & Escalabilidad Mejorada!**
La versión 2.1 se centra en la estabilidad del núcleo del juego, asegurando que los usuarios puedan entrar, salir y reanudar competencias masivas sin fricción.

### ✅ Nuevas Mejoras (v2.1)
1.  **Persistencia Absoluta:**
    *   Arreglo crítico en la detección de participantes. Ahora el sistema reconoce inequívocamente a los jugadores reincidentes usando su `Auth UUID`, eliminando el error de "Acceso Denegado" al volver a entrar.
    *   **Leaver Buster Inteligente:** El sistema de penalización se ha refinado para aplicar *solo* en minijuegos competitivos cortos, permitiendo libertad total de movimiento en el Evento Principal.
2.  **Integridad de Datos:**
    *   Normalización de base de datos mejorada (3NF).
    *   Uso estricto de Claves Foráneas (`Foreign Keys`) para garantizar que no existan estados "huérfanos".
3.  **Tiendas Configurables & QR (Preservado de v2.0):**
    *   Precios dinámicos, control de stock y validación de entrada física mediante QR.

---

## ⚖️ Análisis de Escalabilidad (10,000 Usuarios)

¿Puede este sistema soportar **10,000 jugadores simultáneos**?

### 🟢 Arquitectura (SÍ SOPORTA)
*   **Base de Datos (PostgreSQL):** La estructura normalizada (`game_players`, `game_requests`) está diseñada para escalar. Con los índices correctos (ya aplicados en las claves foráneas), Postgres maneja millones de filas sin problema.
*   **Backend (Stateless):** Las *Edge Functions* de Supabase (Deno) son efímeras y escalan automáticamente con la demanda. No hay un "servidor central" que se sature.
*   **Cliente (Flutter):** La app es ligera y reactiva, delegando el peso al servidor.

### ⚠️ Cuellos de Botella Potenciales (A CONSIDERAR)
Para llegar a 10,000 **concurrentes** (todos jugando al mismo segundo), se deben vigilar dos puntos:
1.  **Realtime (WebSockets):** Escuchar eventos (como "Me lanzaron un poder") consume conexiones.
    *   *Solución:* El código ya usa filtros (`eq('target_id', myId)`). Esto es CRITICO. Si cada cliente escuchara "todo", el sistema colapsaría. Con el filtro actual, es viable, pero requerirá un Plan Pro/Enterprise de Supabase para soportar 10k conexiones de socket abiertas.
2.  **Escrituras Simultáneas (Power Usage):** Si 5,000 personas atacan a la vez.
    *   *Solución:* La lógica de ataque está encolada en la base de datos (`insert`). Postgres maneja bien la concurrencia, pero se podría requerir un `PgBouncer` (Connection Pooling) si las conexiones directas exceden el límite.

**Veredicto:** La arquitectura de software **SÍ** está lista. La limitante será puramente de **infraestructura (Plan de Supabase)**, no de código.

---

## 🛠️ Estructura Técnica

```
lib/
├── core/                   # Utilidades y configuración
├── features/
│   ├── admin/              # PANEL ADMIN
│   ├── auth/               # Autenticación
│   ├── game/               # Lógica del juego (QR, Pistas, Penalties)
│   └── mall/               # TIENDAS (Módulos de compra)
├── services/               # Supabase Services (Data Layer)
└── main.dart               # Entry Point
```

### Tecnologías
*   **Flutter 3.x**
*   **Supabase** (PostgreSQL, Auth, Realtime, Edge Functions)
*   **Provider** (State Management - Clean Architecture)
*   **Mobile Scanner** (QR Camera)

---

## 🔐 Seguridad - IP Hash Salt

El sistema de anti-cheat usa un hash de IP (`ip_hash`) en el backend para bloquear abusos sin almacenar la IP real.
Para proteger la privacidad, el hash se calcula con un salt secreto.

**Variable requerida (Edge Functions):**
- `IP_HASH_SALT`: cadena secreta usada para calcular `sha256(salt:ip)`.

**Beneficios:**
- Evita exponer la IP real en la base de datos.
- Dificulta la reconstruccion de IPs si se filtra la DB.
- Mantiene la capacidad de bloqueo por IP (anti-bot/multi-cuenta).

**Nota:** Si cambias el `IP_HASH_SALT`, los hashes previos dejan de coincidir.

---

**¡Que comience la aventura! 🏆🎮**
