using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using SkiaSharp;
using SkiaSharp.Views.Windows;
using System;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Windows.ApplicationModel.DynamicDependency;
using Microsoft.Windows.ApplicationModel.WindowsAppRuntime;


namespace SmileyApp;

public static class Program
{
    private static SKSwapChainPanel? canvas;
    private static float hue;


    [STAThread]
    static void Main()
    {

        Application.Start((p) =>
        {
            var context = new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread());
            SynchronizationContext.SetSynchronizationContext(context);

            var window = new Window { Title = "SmileyApp" };

            canvas = new SKSwapChainPanel();
            canvas.PaintSurface += OnPaintSurface;
            canvas.EnableRenderLoop = true;

            window.Content = canvas;
            window.Activate();
        });

    }

    private static void OnPaintSurface(object? sender, SKPaintGLSurfaceEventArgs e)
    {
        SKCanvas canvas = e.Surface.Canvas;
        int width = e.BackendRenderTarget.Width;
        int height = e.BackendRenderTarget.Height;

        hue = (hue + 1f) % 360;
        SKColor faceColor = SKColor.FromHsl(hue, 80, 50);

        canvas.Clear(SKColors.Black);

        using var facePaint = new SKPaint { Style = SKPaintStyle.Fill, Color = faceColor, IsAntialias = true };
        using var outlinePaint = new SKPaint { Style = SKPaintStyle.Stroke, Color = SKColors.White, StrokeWidth = 8, IsAntialias = true };

        float centerX = width / 2f;
        float centerY = height / 2f;
        float radius = Math.Min(width, height) * 0.4f;

        canvas.DrawCircle(centerX, centerY, radius, facePaint);
        canvas.DrawCircle(centerX, centerY, radius, outlinePaint);

        float eyeRadius = radius / 6f;
        float eyeOffsetX = radius / 2.5f;
        float eyeOffsetY = radius / 3f;
        canvas.DrawCircle(centerX - eyeOffsetX, centerY - eyeOffsetY, eyeRadius, outlinePaint);
        canvas.DrawCircle(centerX + eyeOffsetX, centerY - eyeOffsetY, eyeRadius, outlinePaint);

        using var mouthPath = new SKPath();
        var mouthRect = new SKRect(centerX - radius / 2, centerY, centerX + radius / 2, centerY + radius);
        mouthPath.AddArc(mouthRect, 20, 140);
        canvas.DrawPath(mouthPath, outlinePaint);
    }
}
