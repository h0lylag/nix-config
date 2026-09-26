#pragma once

#include <QtCore/QScopedPointer>
#include <QtCore/QStringList>
#include <QtCore/QUrl>
#include <QtWidgets/QWidget>

#include "qwebenginecallback.h"

class QAction;
class QAuthenticator;
class QWebChannel;
class QWebEngineCertificateError;

// This is the Qt 5.15 ABI subset used by TeamSpeak 3.6.2, not a general
// WebEngine replacement. Keep the base classes, one-pointer private storage,
// and order of newly introduced virtual methods identical to Qt's headers.
class QWebEngineScript {
public:
    enum InjectionPoint { Deferred, DocumentReady, DocumentCreation };

    QWebEngineScript();
    ~QWebEngineScript();
    void setSourceCode(const QString &);
    void setName(const QString &);
    void setWorldId(quint32);
    void setInjectionPoint(InjectionPoint);
    void setRunsOnSubFrames(bool);

private:
    void *d = nullptr;
};

class QWebEngineScriptCollection {
public:
    void insert(const QWebEngineScript &);

private:
    void *d = nullptr;
};

class QWebEngineProfile : public QObject {
    Q_OBJECT
public:
    explicit QWebEngineProfile(QObject *parent = nullptr);
    QWebEngineProfile(const QString &, QObject *parent = nullptr);
    ~QWebEngineProfile() override;
    void setCachePath(const QString &);
    void setPersistentStoragePath(const QString &);
    QWebEngineScriptCollection *scripts() const;

private:
    struct Private;
    QScopedPointer<Private> d;
};

class QWebEnginePage : public QObject {
    Q_OBJECT
public:
    // Only named values needed by the shim; all Qt 5.15 actions are accepted.
    enum WebAction { NoWebAction = -1, Back, Forward, Stop, Reload, WebActionCount = 45 };
    enum WebWindowType { WebBrowserWindow, WebBrowserTab, WebDialog, WebBrowserBackgroundTab };
    enum FileSelectionMode { FileSelectOpen, FileSelectOpenMultiple };
    enum JavaScriptConsoleMessageLevel { InfoMessageLevel, WarningMessageLevel, ErrorMessageLevel };
    enum NavigationType {
        NavigationTypeLinkClicked, NavigationTypeTyped, NavigationTypeFormSubmitted,
        NavigationTypeBackForward, NavigationTypeReload, NavigationTypeOther,
        NavigationTypeRedirect
    };

    explicit QWebEnginePage(QObject *parent = nullptr);
    QWebEnginePage(QWebEngineProfile *, QObject *parent = nullptr);
    ~QWebEnginePage() override;
    QWidget *view() const;
    QAction *action(WebAction) const;
    virtual void triggerAction(WebAction, bool checked = false);
    bool event(QEvent *) override;
    void load(const QUrl &);
    void setUrl(const QUrl &);
    void setWebChannel(QWebChannel *);
    void runJavaScript(const QString &, const QWebEngineCallback<const QVariant &> &);
    QWebEngineScriptCollection &scripts();

Q_SIGNALS:
    void loadStarted();
    void loadProgress(int);
    void loadFinished(bool);
    void authenticationRequired(const QUrl &, QAuthenticator *);

protected:
    virtual QWebEnginePage *createWindow(WebWindowType);
    virtual QStringList chooseFiles(FileSelectionMode, const QStringList &, const QStringList &);
    virtual void javaScriptAlert(const QUrl &, const QString &);
    virtual bool javaScriptConfirm(const QUrl &, const QString &);
    virtual bool javaScriptPrompt(const QUrl &, const QString &, const QString &, QString *);
    virtual void javaScriptConsoleMessage(JavaScriptConsoleMessageLevel, const QString &, int, const QString &);
    virtual bool certificateError(const QWebEngineCertificateError &);
    virtual bool acceptNavigationRequest(const QUrl &, NavigationType, bool);

private:
    friend class QWebEngineView;
    struct Private;
    QScopedPointer<Private> d;
};

class QWebEngineView : public QWidget {
    Q_OBJECT
public:
    explicit QWebEngineView(QWidget *parent = nullptr);
    ~QWebEngineView() override;
    QWebEnginePage *page() const;
    void setPage(QWebEnginePage *);
    void load(const QUrl &);
    QAction *pageAction(QWebEnginePage::WebAction) const;
    QSize sizeHint() const override;

Q_SIGNALS:
    void loadStarted();
    void loadProgress(int);
    void loadFinished(bool);

protected:
    virtual QWebEngineView *createWindow(QWebEnginePage::WebWindowType);
    void contextMenuEvent(QContextMenuEvent *) override;
    bool event(QEvent *) override;
    void showEvent(QShowEvent *) override;
    void hideEvent(QHideEvent *) override;
    void closeEvent(QCloseEvent *) override;
    void dragEnterEvent(QDragEnterEvent *) override;
    void dragLeaveEvent(QDragLeaveEvent *) override;
    void dragMoveEvent(QDragMoveEvent *) override;
    void dropEvent(QDropEvent *) override;

private:
    friend class QWebEnginePage;
    struct Private;
    QScopedPointer<Private> d;
};
