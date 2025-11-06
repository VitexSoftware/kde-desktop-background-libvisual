#include <QApplication>
#include <QWidget>
#include <QLabel>
#include <QVBoxLayout>
#include <iostream>

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    
    QWidget window;
    QVBoxLayout* layout = new QVBoxLayout(&window);
    
    QLabel* label = new QLabel("Qt6 Test - LibVisual Background", &window);
    layout->addWidget(label);
    
    window.setWindowTitle("Qt6 Test");
    window.resize(300, 100);
    window.show();
    
    std::cout << "Qt6 test application started" << std::endl;
    
    return app.exec();
}