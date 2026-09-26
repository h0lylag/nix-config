#include "stub.h"

#include <QtCore/QHash>
#include <QtCore/QPointer>
#include <QtCore/QTimer>
#include <QtWidgets/QAction>
#include <QtWidgets/QLabel>
#include <QtWidgets/QVBoxLayout>
#include <utility>

// Use Qt's actual callback layout and friend interface, including its shared
// ownership. A callback created by the proprietary client must remain alive
// until completion, and must receive an invalid result when JS is unavailable.
namespace QtWebEngineCore {
class CallbackDirectory {
public:
    static void fail(const QWebEngineCallback<const QVariant &> &callback)
    {
        if (callback.d)
            (*callback.d)(QVariant());
    }
};
}

struct QWebEngineProfile::Private {
    QWebEngineScriptCollection scripts;
};

struct QWebEnginePage::Private {
    QWebEngineView *view = nullptr;
    QWebEngineScriptCollection scripts;
    QHash<int, QAction *> actions;
    QList<QWebEngineCallback<const QVariant &>> callbacks;
};

struct QWebEngineView::Private {
    QWebEnginePage *page = nullptr;
    bool ownsPage = false;
};

// TeamSpeak allocates these objects itself and derives from Page and View.
static_assert(sizeof(QWebEngineProfile) == sizeof(QObject) + sizeof(void *));
static_assert(sizeof(QWebEnginePage) == sizeof(QObject) + sizeof(void *));
static_assert(sizeof(QWebEngineView) == sizeof(QWidget) + sizeof(void *));
static_assert(sizeof(QWebEngineScript) == sizeof(void *));
static_assert(sizeof(QWebEngineScriptCollection) == sizeof(void *));

// Scripts are inert value objects: initialized storage, safe destruction, and
// no JavaScript engine, retained source code, or process-global dummy objects.
QWebEngineScript::QWebEngineScript() = default;
QWebEngineScript::~QWebEngineScript() = default;
void QWebEngineScript::setSourceCode(const QString &) {}
void QWebEngineScript::setName(const QString &) {}
void QWebEngineScript::setWorldId(quint32) {}
void QWebEngineScript::setInjectionPoint(InjectionPoint) {}
void QWebEngineScript::setRunsOnSubFrames(bool) {}
void QWebEngineScriptCollection::insert(const QWebEngineScript &) {}

QWebEngineProfile::QWebEngineProfile(QObject *parent)
    : QObject(parent), d(new Private) {}
QWebEngineProfile::QWebEngineProfile(const QString &, QObject *parent)
    : QWebEngineProfile(parent) {}
QWebEngineProfile::~QWebEngineProfile() = default;
void QWebEngineProfile::setCachePath(const QString &) {}
void QWebEngineProfile::setPersistentStoragePath(const QString &) {}
QWebEngineScriptCollection *QWebEngineProfile::scripts() const { return &d->scripts; }

QWebEnginePage::QWebEnginePage(QObject *parent)
    : QWebEnginePage(nullptr, parent) {}
QWebEnginePage::QWebEnginePage(QWebEngineProfile *, QObject *parent)
    : QObject(parent), d(new Private) {}
QWebEnginePage::~QWebEnginePage()
{
    if (d->view) {
        d->view->d->page = nullptr;
        d->view->d->ownsPage = false;
    }
    const auto callbacks = std::exchange(d->callbacks, {});
    for (const auto &callback : callbacks)
        QtWebEngineCore::CallbackDirectory::fail(callback);
}

QWidget *QWebEnginePage::view() const { return d->view; }
QAction *QWebEnginePage::action(WebAction action) const
{
    if (action < Back || action >= WebActionCount)
        return nullptr;
    auto &result = d->actions[static_cast<int>(action)];
    if (!result) {
        result = new QAction(const_cast<QWebEnginePage *>(this));
        result->setEnabled(false);
    }
    return result;
}
void QWebEnginePage::triggerAction(WebAction, bool) {}
bool QWebEnginePage::event(QEvent *event) { return QObject::event(event); }
void QWebEnginePage::load(const QUrl &)
{
    // Complete asynchronously, like a real load, so callers can connect after
    // load(). Context ownership cancels the timer if the page is destroyed.
    QTimer::singleShot(0, this, [this] {
        QPointer<QWebEnginePage> alive(this);
        Q_EMIT loadStarted();
        if (!alive)
            return;
        Q_EMIT loadProgress(0);
        if (alive)
            Q_EMIT loadFinished(false);
    });
}
void QWebEnginePage::setUrl(const QUrl &url) { load(url); }
void QWebEnginePage::setWebChannel(QWebChannel *) {}
void QWebEnginePage::runJavaScript(const QString &, const QWebEngineCallback<const QVariant &> &callback)
{
    if (!callback)
        return;
    d->callbacks.append(callback);
    QTimer::singleShot(0, this, [this] {
        // A callback may delete this page. Move the whole batch to local
        // storage before invoking any client code.
        const auto callbacks = std::exchange(d->callbacks, {});
        for (const auto &pending : callbacks)
            QtWebEngineCore::CallbackDirectory::fail(pending);
    });
}
QWebEngineScriptCollection &QWebEnginePage::scripts() { return d->scripts; }
QWebEnginePage *QWebEnginePage::createWindow(WebWindowType) { return nullptr; }
QStringList QWebEnginePage::chooseFiles(FileSelectionMode, const QStringList &, const QStringList &) { return {}; }
void QWebEnginePage::javaScriptAlert(const QUrl &, const QString &) {}
bool QWebEnginePage::javaScriptConfirm(const QUrl &, const QString &) { return false; }
bool QWebEnginePage::javaScriptPrompt(const QUrl &, const QString &, const QString &, QString *result)
{
    if (result)
        result->clear();
    return false;
}
void QWebEnginePage::javaScriptConsoleMessage(JavaScriptConsoleMessageLevel, const QString &, int, const QString &) {}
bool QWebEnginePage::certificateError(const QWebEngineCertificateError &) { return false; }
bool QWebEnginePage::acceptNavigationRequest(const QUrl &, NavigationType, bool) { return false; }

QWebEngineView::QWebEngineView(QWidget *parent)
    : QWidget(parent), d(new Private)
{
    auto *label = new QLabel(tr("The embedded web browser is disabled in this build.\n"
                               "Browse add-ons at www.myteamspeak.com in your web browser."), this);
    label->setWordWrap(true);
    label->setAlignment(Qt::AlignCenter);
    auto *layout = new QVBoxLayout(this);
    layout->addWidget(label);
}
QWebEngineView::~QWebEngineView()
{
    blockSignals(true);
    setPage(nullptr);
}
QWebEnginePage *QWebEngineView::page() const
{
    if (!d->page) {
        auto *self = const_cast<QWebEngineView *>(this);
        self->setPage(new QWebEnginePage(self));
        d->ownsPage = true;
    }
    return d->page;
}
void QWebEngineView::setPage(QWebEnginePage *page)
{
    if (d->page == page)
        return;

    auto *oldPage = d->page;
    const bool deleteOldPage = d->ownsPage;
    if (oldPage) {
        disconnect(oldPage, nullptr, this, nullptr);
        oldPage->d->view = nullptr;
    }
    d->page = page;
    d->ownsPage = false;

    if (page) {
        if (auto *oldView = page->d->view) {
            disconnect(page, nullptr, oldView, nullptr);
            d->ownsPage = oldView->d->ownsPage;
            oldView->d->page = nullptr;
            oldView->d->ownsPage = false;
            if (d->ownsPage)
                page->setParent(this);
        }
        page->d->view = this;
        connect(page, &QWebEnginePage::loadStarted, this, &QWebEngineView::loadStarted);
        connect(page, &QWebEnginePage::loadProgress, this, &QWebEngineView::loadProgress);
        connect(page, &QWebEnginePage::loadFinished, this, &QWebEngineView::loadFinished);
    }
    if (deleteOldPage)
        delete oldPage;
}
void QWebEngineView::load(const QUrl &url) { page()->load(url); }
QAction *QWebEngineView::pageAction(QWebEnginePage::WebAction action) const { return page()->action(action); }
QSize QWebEngineView::sizeHint() const { return QWidget::sizeHint(); }
QWebEngineView *QWebEngineView::createWindow(QWebEnginePage::WebWindowType) { return nullptr; }
bool QWebEngineView::event(QEvent *event) { return QWidget::event(event); }
void QWebEngineView::contextMenuEvent(QContextMenuEvent *event) { QWidget::contextMenuEvent(event); }
void QWebEngineView::showEvent(QShowEvent *event) { QWidget::showEvent(event); }
void QWebEngineView::hideEvent(QHideEvent *event) { QWidget::hideEvent(event); }
void QWebEngineView::closeEvent(QCloseEvent *event) { QWidget::closeEvent(event); }
void QWebEngineView::dragEnterEvent(QDragEnterEvent *event) { QWidget::dragEnterEvent(event); }
void QWebEngineView::dragLeaveEvent(QDragLeaveEvent *event) { QWidget::dragLeaveEvent(event); }
void QWebEngineView::dragMoveEvent(QDragMoveEvent *event) { QWidget::dragMoveEvent(event); }
void QWebEngineView::dropEvent(QDropEvent *event) { QWidget::dropEvent(event); }
