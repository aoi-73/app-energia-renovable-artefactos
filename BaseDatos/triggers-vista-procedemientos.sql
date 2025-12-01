-- ============================
-- TRIGGERS Y PROCEDIMIENTOS ALMACENADOS
-- Aplicación Educativa de Energías Renovables
-- ============================

-- ============================
-- TRIGGER 1: Actualizar Racha del Estudiante
-- Se activa cuando se completa una lección
-- ============================
GO
CREATE TRIGGER TRG_ActualizarRacha
ON Progreso_Estudiante
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo se ejecuta cuando el estado cambia a 'completado'
    IF UPDATE(estado)
    BEGIN
        DECLARE @id_usuario VARCHAR(50);
        DECLARE @fecha_ultima DATE;
        DECLARE @fecha_actual DATE = CAST(GETDATE() AS DATE);
        DECLARE @racha_actual INT;
        
        -- Cursor para procesar cada estudiante que completó una lección
        DECLARE cur CURSOR FOR
        SELECT DISTINCT i.id_usuario
        FROM inserted i
        INNER JOIN deleted d ON i.id_usuario = d.id_usuario AND i.id_leccion = d.id_leccion
        WHERE i.estado = 'completado' AND d.estado <> 'completado';
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @id_usuario;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Obtener la fecha de última actividad y racha actual
            SELECT @fecha_ultima = fecha_ultima_actividad, @racha_actual = racha
            FROM Estudiante
            WHERE id_usuario = @id_usuario;
            
            -- Lógica de racha: si la actividad fue ayer, aumentar; si fue hoy, mantener; si no, reiniciar
            IF @fecha_ultima IS NULL OR DATEDIFF(DAY, @fecha_ultima, @fecha_actual) > 1
            BEGIN
                -- Reiniciar racha
                UPDATE Estudiante
                SET racha = 1, fecha_ultima_actividad = @fecha_actual
                WHERE id_usuario = @id_usuario;
            END
            ELSE IF DATEDIFF(DAY, @fecha_ultima, @fecha_actual) = 1
            BEGIN
                -- Incrementar racha (actividad diaria continua)
                UPDATE Estudiante
                SET racha = racha + 1, fecha_ultima_actividad = @fecha_actual
                WHERE id_usuario = @id_usuario;
            END
            ELSE IF DATEDIFF(DAY, @fecha_ultima, @fecha_actual) = 0
            BEGIN
                -- Mismo día, solo actualizar fecha
                UPDATE Estudiante
                SET fecha_ultima_actividad = @fecha_actual
                WHERE id_usuario = @id_usuario;
            END
            
            FETCH NEXT FROM cur INTO @id_usuario;
        END
        
        CLOSE cur;
        DEALLOCATE cur;
    END
END;
GO

-- ============================
-- TRIGGER 2: Otorgar Logros Automáticamente
-- Se activa al actualizar puntos o rachas del estudiante
-- ============================
GO
CREATE TRIGGER TRG_OtorgarLogros
ON Estudiante
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @id_usuario VARCHAR(50);
    DECLARE @puntos INT;
    DECLARE @racha INT;
    DECLARE @id_logro INT;
    DECLARE @requisito_tipo VARCHAR(50);
    DECLARE @requisito_valor INT;
    
    -- Cursor para cada estudiante actualizado
    DECLARE cur_estudiante CURSOR FOR
    SELECT id_usuario, puntos_totales, racha
    FROM inserted;
    
    OPEN cur_estudiante;
    FETCH NEXT FROM cur_estudiante INTO @id_usuario, @puntos, @racha;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Verificar logros por puntos
        DECLARE cur_logros CURSOR FOR
        SELECT id_logro, requisito_tipo, requisito_valor
        FROM Logro
        WHERE activo = 1 AND requisito_tipo IN ('puntos', 'racha');
        
        OPEN cur_logros;
        FETCH NEXT FROM cur_logros INTO @id_logro, @requisito_tipo, @requisito_valor;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Verificar si cumple el requisito y no lo tiene aún
            IF (@requisito_tipo = 'puntos' AND @puntos >= @requisito_valor)
               OR (@requisito_tipo = 'racha' AND @racha >= @requisito_valor)
            BEGIN
                -- Otorgar logro si no lo tiene
                IF NOT EXISTS (
                    SELECT 1 FROM Estudiante_Logro
                    WHERE id_usuario = @id_usuario AND id_logro = @id_logro
                )
                BEGIN
                    INSERT INTO Estudiante_Logro (id_usuario, id_logro, fecha_obtenido, notificado)
                    VALUES (@id_usuario, @id_logro, GETDATE(), 0);
                    
                    -- Crear notificación
                    INSERT INTO Notificacion (id_usuario, titulo, mensaje, tipo, leida)
                    SELECT @id_usuario, 
                           '¡Nuevo Logro Desbloqueado!',
                           'Has obtenido el logro: ' + nombre,
                           'logro',
                           0
                    FROM Logro WHERE id_logro = @id_logro;
                END
            END
            
            FETCH NEXT FROM cur_logros INTO @id_logro, @requisito_tipo, @requisito_valor;
        END
        
        CLOSE cur_logros;
        DEALLOCATE cur_logros;
        
        FETCH NEXT FROM cur_estudiante INTO @id_usuario, @puntos, @racha;
    END
    
    CLOSE cur_estudiante;
    DEALLOCATE cur_estudiante;
END;
GO

-- ============================
-- TRIGGER 3: Actualizar Puntos al Completar Lección
-- ============================
GO
CREATE TRIGGER TRG_ActualizarPuntosPorLeccion
ON Progreso_Estudiante
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(estado) OR UPDATE(puntos_obtenidos)
    BEGIN
        -- Actualizar puntos totales del estudiante
        UPDATE E
        SET E.puntos_totales = E.puntos_totales + (i.puntos_obtenidos - ISNULL(d.puntos_obtenidos, 0)),
            E.experiencia = E.experiencia + (i.puntos_obtenidos - ISNULL(d.puntos_obtenidos, 0))
        FROM Estudiante E
        INNER JOIN inserted i ON E.id_usuario = i.id_usuario
        INNER JOIN deleted d ON i.id_usuario = d.id_usuario AND i.id_leccion = d.id_leccion
        WHERE i.puntos_obtenidos > ISNULL(d.puntos_obtenidos, 0);
        
        -- Actualizar nivel basado en experiencia (cada 1000 puntos = 1 nivel)
        UPDATE Estudiante
        SET nivel = (experiencia / 1000) + 1
        WHERE id_usuario IN (SELECT DISTINCT id_usuario FROM inserted);
    END
END;
GO

-- ============================
-- TRIGGER 4: Registrar Sesión al Actualizar Último Acceso
-- ============================
GO
CREATE TRIGGER TRG_RegistrarSesion
ON Usuario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(ultimo_acceso)
    BEGIN
        -- Insertar nueva sesión para cada usuario que actualizó su acceso
        INSERT INTO Sesion (id_usuario, fecha_conexion, dispositivo, version_app)
        SELECT i.id_usuario, 
               i.ultimo_acceso,
               'Dispositivo móvil', -- Por defecto, puede parametrizarse
               '2.0'
        FROM inserted i
        INNER JOIN deleted d ON i.id_usuario = d.id_usuario
        WHERE i.ultimo_acceso > ISNULL(d.ultimo_acceso, '1900-01-01');
    END
END;
GO

-- ============================
-- TRIGGER 5: Validar Intentos de Evaluación
-- ============================
GO
CREATE TRIGGER TRG_ValidarIntentosEvaluacion
ON Intento_Evaluacion
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @id_usuario VARCHAR(50);
    DECLARE @id_evaluacion INT;
    DECLARE @intentos_realizados INT;
    DECLARE @intentos_permitidos INT;
    
    DECLARE cur CURSOR FOR
    SELECT id_usuario, id_evaluacion FROM inserted;
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @id_usuario, @id_evaluacion;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Contar intentos previos
        SELECT @intentos_realizados = COUNT(*)
        FROM Intento_Evaluacion
        WHERE id_usuario = @id_usuario AND id_evaluacion = @id_evaluacion;
        
        -- Obtener intentos permitidos
        SELECT @intentos_permitidos = intentos_permitidos
        FROM Evaluacion
        WHERE id_evaluacion = @id_evaluacion;
        
        -- Validar si puede realizar el intento
        IF @intentos_realizados < @intentos_permitidos
        BEGIN
            -- Permitir inserción
            INSERT INTO Intento_Evaluacion (
                id_usuario, id_evaluacion, fecha_intento, puntuacion_obtenida,
                puntuacion_maxima, tiempo_empleado, aprobado, respuestas, numero_intento
            )
            SELECT 
                id_usuario, id_evaluacion, fecha_intento, puntuacion_obtenida,
                puntuacion_maxima, tiempo_empleado, aprobado, respuestas, @intentos_realizados + 1
            FROM inserted
            WHERE id_usuario = @id_usuario AND id_evaluacion = @id_evaluacion;
        END
        ELSE
        BEGIN
            -- Registrar notificación de límite alcanzado
            INSERT INTO Notificacion (id_usuario, titulo, mensaje, tipo)
            VALUES (@id_usuario, 
                    'Límite de intentos alcanzado',
                    'Has alcanzado el número máximo de intentos para esta evaluación.',
                    'sistema');
        END
        
        FETCH NEXT FROM cur INTO @id_usuario, @id_evaluacion;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- ============================
-- PROCEDIMIENTO 1: Inscribir Estudiante en Módulo
-- ============================
GO
CREATE PROCEDURE SP_InscribirEstudianteModulo
    @id_usuario VARCHAR(50),
    @id_modulo INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar prerequisitos del módulo
        DECLARE @prerequisitos VARCHAR(255);
        SELECT @prerequisitos = prerequisitos FROM Modulo WHERE id_modulo = @id_modulo;
        
        IF @prerequisitos IS NOT NULL AND LEN(@prerequisitos) > 0
        BEGIN
            -- Verificar que el estudiante haya completado los prerequisitos
            DECLARE @prerequisito_id INT;
            DECLARE @todos_completados BIT = 1;
            
            DECLARE cur CURSOR FOR
            SELECT CAST(value AS INT) 
            FROM STRING_SPLIT(@prerequisitos, ',');
            
            OPEN cur;
            FETCH NEXT FROM cur INTO @prerequisito_id;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Verificar si completó todas las lecciones del módulo prerequisito
                IF NOT EXISTS (
                    SELECT 1 
                    FROM Progreso_Estudiante pe
                    INNER JOIN Leccion l ON pe.id_leccion = l.id_leccion
                    WHERE pe.id_usuario = @id_usuario 
                      AND l.id_modulo = @prerequisito_id
                      AND pe.estado = 'completado'
                    HAVING COUNT(*) = (SELECT COUNT(*) FROM Leccion WHERE id_modulo = @prerequisito_id)
                )
                BEGIN
                    SET @todos_completados = 0;
                    BREAK;
                END
                
                FETCH NEXT FROM cur INTO @prerequisito_id;
            END
            
            CLOSE cur;
            DEALLOCATE cur;
            
            IF @todos_completados = 0
            BEGIN
                RAISERROR('No has completado los módulos prerequisitos requeridos.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END
        
        -- Inscribir al estudiante en todas las lecciones del módulo
        INSERT INTO Progreso_Estudiante (id_usuario, id_leccion, estado, fecha_inicio)
        SELECT @id_usuario, id_leccion, 'no_iniciado', GETDATE()
        FROM Leccion
        WHERE id_modulo = @id_modulo
          AND NOT EXISTS (
              SELECT 1 FROM Progreso_Estudiante 
              WHERE id_usuario = @id_usuario AND id_leccion = Leccion.id_leccion
          );
        
        -- Crear notificación
        INSERT INTO Notificacion (id_usuario, titulo, mensaje, tipo)
        SELECT @id_usuario, 
               'Inscripción Exitosa',
               'Te has inscrito en el módulo: ' + titulo,
               'sistema'
        FROM Modulo WHERE id_modulo = @id_modulo;
        
        COMMIT TRANSACTION;
        
        SELECT 'Inscripción exitosa' AS Resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- ============================
-- PROCEDIMIENTO 2: Calcular y Actualizar Ranking
-- ============================
GO
CREATE PROCEDURE SP_ActualizarRanking
    @periodo VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Limpiar ranking anterior del periodo
        DELETE FROM Ranking WHERE periodo = @periodo;
        
        -- Calcular nuevas posiciones
        WITH RankingCTE AS (
            SELECT 
                id_usuario,
                puntos_totales,
                ROW_NUMBER() OVER (ORDER BY puntos_totales DESC, fecha_ultima_actividad DESC) AS posicion
            FROM Estudiante
            WHERE fecha_ultima_actividad >= 
                CASE @periodo
                    WHEN 'semanal' THEN DATEADD(WEEK, -1, GETDATE())
                    WHEN 'mensual' THEN DATEADD(MONTH, -1, GETDATE())
                    WHEN 'anual' THEN DATEADD(YEAR, -1, GETDATE())
                    ELSE '1900-01-01' -- global
                END
        )
        INSERT INTO Ranking (id_usuario, posicion, puntos, periodo, fecha_actualizacion)
        SELECT id_usuario, posicion, puntos_totales, @periodo, GETDATE()
        FROM RankingCTE;
        
        -- Notificar a los top 10
        INSERT INTO Notificacion (id_usuario, titulo, mensaje, tipo)
        SELECT 
            id_usuario,
            '¡Estás en el Top 10!',
            'Felicidades, estás en la posición ' + CAST(posicion AS VARCHAR) + ' del ranking ' + @periodo,
            'sistema'
        FROM Ranking
        WHERE periodo = @periodo AND posicion <= 10;
        
        COMMIT TRANSACTION;
        
        SELECT 'Ranking actualizado exitosamente' AS Resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- ============================
-- PROCEDIMIENTO 3: Generar Retroalimentación Personalizada
-- ============================
GO
CREATE PROCEDURE SP_GenerarRetroalimentacion
    @id_intento INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @puntuacion_obtenida INT;
    DECLARE @puntuacion_maxima INT;
    DECLARE @porcentaje DECIMAL(5,2);
    DECLARE @nivel_superacion VARCHAR(50);
    DECLARE @recomendaciones VARCHAR(MAX);
    DECLARE @titulo VARCHAR(255);
    
    -- Obtener datos del intento
    SELECT 
        @puntuacion_obtenida = puntuacion_obtenida,
        @puntuacion_maxima = puntuacion_maxima
    FROM Intento_Evaluacion
    WHERE id_intento = @id_intento;
    
    -- Calcular porcentaje
    SET @porcentaje = (@puntuacion_obtenida * 100.0) / @puntuacion_maxima;
    
    -- Determinar nivel de superación
    IF @porcentaje >= 90
    BEGIN
        SET @nivel_superacion = 'excelente';
        SET @titulo = '¡Excelente trabajo!';
        SET @recomendaciones = 'Has demostrado un dominio sobresaliente del tema. Te recomendamos continuar con módulos más avanzados.';
    END
    ELSE IF @porcentaje >= 70
    BEGIN
        SET @nivel_superacion = 'bueno';
        SET @titulo = 'Buen desempeño';
        SET @recomendaciones = 'Has logrado un buen entendimiento. Revisa los conceptos donde tuviste menor puntuación para fortalecer tu conocimiento.';
    END
    ELSE IF @porcentaje >= 50
    BEGIN
        SET @nivel_superacion = 'regular';
        SET @titulo = 'Resultado regular';
        SET @recomendaciones = 'Es importante que repases el contenido del módulo. Te sugerimos revisar los videos y recursos adicionales.';
    END
    ELSE
    BEGIN
        SET @nivel_superacion = 'necesita_mejorar';
        SET @titulo = 'Necesitas repasar';
        SET @recomendaciones = 'Te recomendamos volver a estudiar el módulo completo, prestando especial atención a los conceptos fundamentales. No te desanimes, ¡el aprendizaje es un proceso!';
    END
    
    -- Insertar retroalimentación
    INSERT INTO Retroalimentacion (
        id_intento, titulo, contenido, nivel_superacion, 
        recomendaciones, fecha_generacion
    )
    VALUES (
        @id_intento,
        @titulo,
        'Obtuviste ' + CAST(@puntuacion_obtenida AS VARCHAR) + ' de ' + 
        CAST(@puntuacion_maxima AS VARCHAR) + ' puntos (' + 
        CAST(CAST(@porcentaje AS INT) AS VARCHAR) + '%).',
        @nivel_superacion,
        @recomendaciones,
        GETDATE()
    );
    
    SELECT 'Retroalimentación generada exitosamente' AS Resultado;
END;
GO

-- ============================
-- PROCEDIMIENTO 4: Obtener Dashboard del Estudiante
-- ============================
GO
CREATE PROCEDURE SP_ObtenerDashboardEstudiante
    @id_usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Información general del estudiante
    SELECT 
        U.nombre + ' ' + ISNULL(U.apellido, '') AS nombre_completo,
        E.puntos_totales,
        E.nivel,
        E.racha,
        E.experiencia,
        E.grado,
        E.institucion
    FROM Estudiante E
    INNER JOIN Usuario U ON E.id_usuario = U.id_usuario
    WHERE E.id_usuario = @id_usuario;
    
    -- Progreso por módulo
    SELECT 
        M.titulo AS modulo,
        M.tipo_energia,
        COUNT(CASE WHEN PE.estado = 'completado' THEN 1 END) AS lecciones_completadas,
        COUNT(*) AS total_lecciones,
        CAST(COUNT(CASE WHEN PE.estado = 'completado' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS porcentaje_avance
    FROM Modulo M
    INNER JOIN Leccion L ON M.id_modulo = L.id_modulo
    LEFT JOIN Progreso_Estudiante PE ON L.id_leccion = PE.id_leccion AND PE.id_usuario = @id_usuario
    WHERE M.activo = 1
    GROUP BY M.id_modulo, M.titulo, M.tipo_energia
    ORDER BY M.orden_secuencial;
    
    -- Logros obtenidos
    SELECT 
        L.nombre,
        L.descripcion,
        L.categoria,
        EL.fecha_obtenido
    FROM Estudiante_Logro EL
    INNER JOIN Logro L ON EL.id_logro = L.id_logro
    WHERE EL.id_usuario = @id_usuario
    ORDER BY EL.fecha_obtenido DESC;
    
    -- Actividad reciente
    SELECT TOP 5
        'Lección completada' AS tipo_actividad,
        Lec.titulo AS detalle,
        PE.fecha_completado AS fecha
    FROM Progreso_Estudiante PE
    INNER JOIN Leccion Lec ON PE.id_leccion = Lec.id_leccion
    WHERE PE.id_usuario = @id_usuario AND PE.estado = 'completado'
    ORDER BY PE.fecha_completado DESC;
    
    -- Posición en ranking
    SELECT 
        periodo,
        posicion,
        puntos
    FROM Ranking
    WHERE id_usuario = @id_usuario
    ORDER BY 
        CASE periodo
            WHEN 'semanal' THEN 1
            WHEN 'mensual' THEN 2
            WHEN 'anual' THEN 3
            ELSE 4
        END;
END;
GO

-- ============================
-- PROCEDIMIENTO 5: Descargar Módulo para Modo Offline
-- ============================
GO
CREATE PROCEDURE SP_DescargarModuloOffline
    @id_usuario VARCHAR(50),
    @id_modulo INT,
    @dias_expiracion INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar si ya está descargado
        IF EXISTS (
            SELECT 1 FROM Contenido_Descargado
            WHERE id_usuario = @id_usuario 
              AND id_modulo = @id_modulo
              AND estado = 'disponible'
              AND fecha_expiracion > GETDATE()
        )
        BEGIN
            SELECT 'El módulo ya está descargado y disponible' AS Resultado;
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Calcular tamaño total del módulo (suma de recursos multimedia)
        DECLARE @tamano_total DECIMAL(10,2);
        
        SELECT @tamano_total = ISNULL(SUM(RM.tamano_mb), 0)
        FROM Leccion L
        INNER JOIN Leccion_Recursos LR ON L.id_leccion = LR.id_leccion
        INNER JOIN RecursosMultimedia RM ON LR.id_recurso = RM.id_recurso
        WHERE L.id_modulo = @id_modulo;
        
        -- Marcar recursos como disponibles offline
        UPDATE RecursosMultimedia
        SET disponible_offline = 1
        WHERE id_recurso IN (
            SELECT DISTINCT LR.id_recurso
            FROM Leccion L
            INNER JOIN Leccion_Recursos LR ON L.id_leccion = LR.id_leccion
            WHERE L.id_modulo = @id_modulo
        );
        
        -- Registrar descarga
        IF EXISTS (SELECT 1 FROM Contenido_Descargado WHERE id_usuario = @id_usuario AND id_modulo = @id_modulo)
        BEGIN
            -- Actualizar descarga existente
            UPDATE Contenido_Descargado
            SET fecha_descarga = GETDATE(),
                fecha_expiracion = DATEADD(DAY, @dias_expiracion, GETDATE()),
                tamano_total_mb = @tamano_total,
                estado = 'disponible'
            WHERE id_usuario = @id_usuario AND id_modulo = @id_modulo;
        END
        ELSE
        BEGIN
            -- Nueva descarga
            INSERT INTO Contenido_Descargado (
                id_usuario, id_modulo, fecha_descarga, fecha_expiracion, 
                tamano_total_mb, estado
            )
            VALUES (
                @id_usuario, @id_modulo, GETDATE(), 
                DATEADD(DAY, @dias_expiracion, GETDATE()),
                @tamano_total, 'disponible'
            );
        END
        
        -- Notificar al usuario
        INSERT INTO Notificacion (id_usuario, titulo, mensaje, tipo)
        SELECT @id_usuario,
               'Módulo descargado',
               'El módulo "' + titulo + '" está disponible offline por ' + 
               CAST(@dias_expiracion AS VARCHAR) + ' días.',
               'sistema'
        FROM Modulo WHERE id_modulo = @id_modulo;
        
        COMMIT TRANSACTION;
        
        SELECT 
            'Descarga exitosa' AS Resultado,
            @tamano_total AS tamano_mb,
            DATEADD(DAY, @dias_expiracion, GETDATE()) AS fecha_expiracion;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- ============================
-- EJEMPLOS DE USO
-- ============================

/*
-- Ejemplo 1: Inscribir estudiante en módulo
EXEC SP_InscribirEstudianteModulo @id_usuario = 'EST001', @id_modulo = 1;

-- Ejemplo 2: Actualizar ranking semanal
EXEC SP_ActualizarRanking @periodo = 'semanal';

-- Ejemplo 3: Generar retroalimentación después de evaluación
EXEC SP_GenerarRetroalimentacion @id_intento = 1;

-- Ejemplo 4: Obtener dashboard del estudiante
EXEC SP_ObtenerDashboardEstudiante @id_usuario = 'EST001';

-- Ejemplo 5: Descargar módulo para uso offline
EXEC SP_DescargarModuloOffline @id_usuario = 'EST001', @id_modulo = 1, @dias_expiracion = 30;
*/

-- ============================
-- FIN DEL SCRIPT
-- ============================